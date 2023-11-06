import sys
from collections.abc import Callable, Iterator
from contextlib import contextmanager
from datetime import datetime
from difflib import unified_diff
from pathlib import Path
from time import sleep, time
from typing import NamedTuple, Literal

import docker
import psycopg
from colorama import init
from docker.models.containers import Container
from psycopg import Rollback
from termcolor import cprint, colored
from watchdog.events import (
    FileSystemEventHandler,
    FileSystemEvent,
    FileSystemMovedEvent,
)
from watchdog.observers import Observer

init()


directory = Path(__file__).parent
directory_migrations = directory / "migrations"
directory_tests = directory / "tests"


def migrations():
    return sorted(
        (e for e in directory_migrations.iterdir() if e.is_file() and e.name.split("-")[0].isdigit()),
        key=lambda item: item.name,
    )


@contextmanager
def profile(text: str):
    print(text + "...", end="")
    start = time()
    yield
    end = time()
    diff = end - start
    cprint(f" {round(diff * 1000)}ms", "blue")


def run_migration(conn: psycopg.Connection, running: Callable[[str], None]):
    for file in migrations():
        running(file.name)
        with conn.transaction():
            conn.execute(file.read_text())


def run_tests(
    conn: psycopg.Connection,
    running: Callable[[str], None],
    done: Callable[[str | None], None],
):
    results: dict[str, str | None] = dict()
    for file in directory_tests.iterdir():
        if not file.is_file():
            continue
        running(file.name)
        try:
            run_test(conn, file)
            results[file.name] = None
            done(None)
        except psycopg.errors.DatabaseError as e:
            results[file.name] = str(e)
            done(str(e))

    return results


def run_test(conn: psycopg.Connection, file: Path):
    with conn.transaction():
        if file.suffix == ".sql":
            conn.execute(
                """
CREATE OR REPLACE FUNCTION public.test(expected anyelement, actual anyelement) RETURNS BOOLEAN LANGUAGE 'plpgsql' AS $$
DECLARE
    res BOOLEAN;
BEGIN
    res := expected IS NOT DISTINCT FROM actual;
    IF NOT res THEN
        RAISE NOTICE 'Actual: %', actual::text;
        RAISE NOTICE 'Expected: %', expected::text;
    END IF;
    ASSERT res;
    RETURN res;
END; $$;
CREATE OR REPLACE FUNCTION public.test(expected integer, actual bigint) RETURNS BOOLEAN LANGUAGE 'sql' AS $$
    SELECT test(expected::bigint, actual);
$$;
CREATE OR REPLACE FUNCTION public.test_geom(expected geometry, actual geometry) RETURNS BOOLEAN LANGUAGE 'plpgsql' AS $$
DECLARE
    res BOOLEAN;
BEGIN
    res := (expected IS NULL AND actual IS NULL) OR ST_Equals(expected, actual);
    IF NOT res THEN
        RAISE NOTICE 'Actual: %', ST_AsText(actual);
        RAISE NOTICE 'Expected: %', ST_AsText(expected);
    END IF;
    ASSERT res;
    RETURN res;
END; $$;
CREATE OR REPLACE FUNCTION public.test(name text, expected anyelement, actual anyelement) RETURNS BOOLEAN LANGUAGE 'plpgsql' AS $$
DECLARE
    res BOOLEAN;
BEGIN
    res := expected IS NOT DISTINCT FROM actual;
    IF NOT res THEN
        RAISE NOTICE 'Actual: %', actual::text;
        RAISE NOTICE 'Expected: %', expected::text;
    END IF;
    ASSERT res, FORMAT('assertion failed: %s', name);
    RETURN res;
END; $$;
CREATE OR REPLACE FUNCTION public.test(name text, expected integer, actual bigint) RETURNS BOOLEAN LANGUAGE 'sql' AS $$
    SELECT test(name, expected::bigint, actual);
$$;
            """
            )
            conn.execute(file.read_text())
        raise Rollback()


def run_and_report_tests(conninfo: str):
    with psycopg.connect(conninfo) as conn:
        conn.add_notice_handler(lambda diag: print(diag.message_primary))
        results = run_tests(
            conn,
            lambda name: print(f"  Running {name}...", end=""),
            lambda err: cprint(
                " SUCCESS" if err is None else f" FAILED: {err}",
                "green" if err is None else "red",
            ),
        )
    if any(1 for v in results.values() if v is not None):
        cprint("ERROR: Some tests failed", "red", file=sys.stderr)
    else:
        cprint("All tests succeeded", "green")
    return results


@contextmanager
def setup() -> Iterator[tuple[str, Container]]:
    dkr = docker.from_env()
    with profile("Starting database container"):
        container: Container = dkr.containers.run(
            "ghcr.io/cloudnative-pg/postgis:15-3.4",
            detach=True,
            remove=True,
            ports={"5432/tcp": None},
            environment=dict(
                POSTGRES_PASSWORD="postgres",
                POSTGRES_USER="postgres",
                POSTGRES_DB="app",
            ),
        )
    try:
        while container.status != "running":
            sleep(0.5)
            container.reload()
        conninfo = f"host=localhost port={container.ports['5432/tcp'][0]['HostPort']} dbname=app user=postgres password=postgres"
        with profile("Waiting for container startup"):
            while True:
                try:
                    with psycopg.connect(conninfo) as conn:
                        conn.execute("SELECT 1")
                        break
                except psycopg.Error:
                    sleep(0.5)
                    pass

        with psycopg.connect(conninfo) as conn:
            conn.execute("CREATE ROLE app")
            conn.execute("CREATE ROLE web_anon WITH NOLOGIN NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION")
            conn.execute("CREATE ROLE web_auth WITH NOLOGIN NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION")
            conn.execute(
                "CREATE ROLE web_tileserv WITH NOLOGIN NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION"
            )

        yield conninfo, container
    except psycopg.errors.ProgrammingError as e:
        print(str(e), file=sys.stderr)
    finally:
        container.stop()


def test():
    with setup() as (conninfo, container):
        print("Running first pass of migration...")
        with psycopg.connect(conninfo) as conn:
            run_migration(conn, lambda name: print(f"  Running {name}..."))

        dump_a = pg_dump_schema(container)

        print("Running second pass of migration...")
        with psycopg.connect(conninfo) as conn:
            run_migration(conn, lambda name: print(f"  Running {name}..."))

        dump_b = pg_dump_schema(container)

        if dump_a != dump_b:
            cprint("ERROR: Migrations are not idempotent", "red")
            diff = unified_diff(dump_a, dump_b)
            sys.stdout.writelines(diff)

        print("Running tests...")
        run_and_report_tests(conninfo)


def migrate():
    pass


class Change(NamedTuple):
    at: datetime
    action: Literal["run-test", "run-tests", "run-migration", "run-migrations"]
    file: Path | None = None


class WatchHandler(FileSystemEventHandler):
    def __init__(self, conninfo: str, container: Container):
        self._conninfo = conninfo
        self._container = container
        self._test_results: dict[str, str | None] = dict()
        self._changes: list[Change] = []
        self._run_migrations()

    def on_created(self, event: FileSystemEvent):
        self.on_modified(event)

    def on_moved(self, event: FileSystemMovedEvent):
        if event.src_path.endswith("~") or event.is_directory:
            return
        if event.src_path.startswith(str(directory_migrations)):
            self._changes.append(Change(datetime.now(), "run-migrations"))
        elif event.src_path.startswith(str(directory_tests)):
            if Path(event.src_path).name in self._test_results:
                self._test_results[Path(event.dest_path).name] = self._test_results.pop(Path(event.src_path).name)
                self._print_summary()

    def on_deleted(self, event: FileSystemEvent):
        if event.src_path.endswith("~") or event.is_directory:
            return
        if event.src_path.startswith(str(directory_migrations)):
            self._changes.append(Change(datetime.now(), "run-migrations"))
        elif event.src_path.startswith(str(directory_tests)):
            del self._test_results[Path(event.src_path).name]
            self._print_summary()

    def on_modified(self, event: FileSystemEvent):
        if event.src_path.endswith("~") or event.is_directory:
            return
        if event.src_path.startswith(str(directory_migrations)):
            latest = migrations()[-1]
            if latest == Path(event.src_path):
                self._changes.append(Change(datetime.now(), "run-migration", Path(event.src_path)))
            else:
                self._changes.append(Change(datetime.now(), "run-migrations"))
        elif event.src_path.startswith(str(directory_tests)):
            self._changes.append(Change(datetime.now(), "run-test", Path(event.src_path)))

    def process(self):
        run_migs = next(reversed([c for c in self._changes if c.action == "run-migrations"]), None)
        run_mig = next(reversed([c for c in self._changes if c.action == "run-migration"]), None)
        run_tsts = next(reversed([c for c in self._changes if c.action == "run-tests"]), None)
        if run_migs:
            self._changes = [run_migs]
        elif run_mig:
            self._changes = [run_mig]
        elif run_tsts:
            self._changes = [run_tsts]
        else:
            paths = {c.file for c in self._changes}
            self._changes = sorted(
                [
                    Change(
                        max(c.at for c in self._changes if c.file == path),
                        "run-test",
                        path,
                    )
                    for path in paths
                ],
                key=lambda c: c.at,
            )

        now = datetime.now()
        due = [c for c in self._changes if (now - c.at).total_seconds() > 0.5]
        self._changes = [c for c in self._changes if (now - c.at).total_seconds() <= 0.5]

        for change in due:
            if change.action == "run-migrations":
                self._run_migrations()
            elif change.action == "run-migration":
                self._run_migration(change.file)
            elif change.action == "run-tests":
                self._run_tests()
            elif change.action == "run-test":
                self._run_test(change.file)

    def _run_test(self, file: Path):
        res: list[str] = []
        with profile(f"Running test {file.name}"):
            with psycopg.connect(self._conninfo) as conn:
                conn.add_notice_handler(lambda diag: res.append(diag.message_primary))
                try:
                    run_test(conn, file)
                    self._test_results[file.name] = None
                    res.append(colored("  Succeeded", "green"))
                except psycopg.errors.DatabaseError as e:
                    self._test_results[file.name] = str(e)
                    res.append(colored(f"  FAILED: {str(e)}", "red"))
        for row in res:
            print(row)

    def _run_tests(self):
        print("Running tests...")
        self._test_results = run_and_report_tests(self._conninfo)

    def _run_migration(self, file: Path):
        with profile(f"Running migration {file.name}"):
            with psycopg.connect(self._conninfo) as conn:
                with conn.transaction():
                    conn.execute(file.read_text())
        self._run_tests()

    def _run_migrations(self):
        print("Cleaning up...")
        with psycopg.connect(self._conninfo) as conn:
            conn.execute("DROP SCHEMA IF EXISTS api CASCADE")
            conn.execute("DROP SCHEMA IF EXISTS upstream CASCADE")
            conn.execute("DROP SCHEMA IF EXISTS osm CASCADE")

        print("Running first pass of migration...")
        with psycopg.connect(self._conninfo) as conn:
            run_migration(conn, lambda name: print(f"  Running {name}..."))

        dump_a = pg_dump_schema(self._container)

        print("Running second pass of migration...")
        with psycopg.connect(self._conninfo) as conn:
            run_migration(conn, lambda name: print(f"  Running {name}..."))

        dump_b = pg_dump_schema(self._container)

        if dump_a != dump_b:
            cprint("ERROR: Migrations are not idempotent", "red")
            diff = unified_diff(dump_a, dump_b)
            sys.stdout.writelines(diff)

        self._run_tests()

    def _print_summary(self):
        pass


def watch():
    with setup() as (conninfo, container):
        handler = WatchHandler(conninfo, container)
        observer = Observer()
        observer.schedule(handler, str((directory / "migrations").absolute()), recursive=True)
        observer.schedule(handler, str((directory / "tests").absolute()), recursive=True)
        observer.start()
        try:
            while True:
                handler.process()
                sleep(0.25)
        except KeyboardInterrupt:
            observer.stop()
        observer.join()


def pg_dump_schema(container: Container):
    dump = container.exec_run("pg_dump --schema-only --no-tablespaces -d app", stderr=False)
    return dump.output.decode("utf-8")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        cprint(
            "ERROR: Invalid command, must specify one of test, migrate or watch",
            "red",
            file=sys.stderr,
        )
    elif sys.argv[1] == "test":
        test()
    elif sys.argv[1] == "migrate":
        migrate()
    elif sys.argv[1] == "watch":
        watch()
    else:
        cprint(
            "ERROR: Invalid command, must specify one of test, migrate or watch",
            "red",
            file=sys.stderr,
        )
