import { FC, Suspense } from "react";

import { Burger, Button, Group, AppShell, Loader, Flex, Alert, Menu, rem } from "@mantine/core";
import { Link, Route, Switch, useLocation } from "wouter";

import IndexPage from "./pages/index.tsx";
import MunicipalitiesPage from "./pages/municipalities.tsx";
import MunicipalitiesMapPage from "./pages/municipalities-map.tsx";
import DeviationsPage from "./pages/deviations.tsx";
import DatasetsPage from "./pages/datasets.tsx";
import MunicipalityPage from "./pages/municipality.tsx";
import DeviationPage from "./pages/deviation.tsx";
import DatasetPage from "./pages/dataset.tsx";
import { useDisclosure } from "@mantine/hooks";

import "@mantine/core/styles.css";
import "ol/ol.css";
import classes from "./App.module.css";
import { QueryErrorResetBoundary } from "@tanstack/react-query";
import { ErrorBoundary } from "react-error-boundary";
import { IconExclamationCircle, IconMap, IconTable } from "@tabler/icons-react";
import SystemStatus from "./pages/system-status.tsx";

const App: FC = () => {
  const [opened, { toggle }] = useDisclosure(false);

  const [location] = useLocation();

  return (
    <AppShell
      header={{ height: 60 }}
      navbar={{
        width: 300,
        breakpoint: "sm",
        collapsed: { desktop: true, mobile: !opened },
      }}
      padding="md"
    >
      <AppShell.Header style={{ display: "flex", alignItems: "center" }} px="md">
        <Burger opened={opened} onClick={toggle} hiddenFrom="sm" size="sm" />
        <a href="/" className={classes.brand}>
          BästaJävlaKartan
        </a>

        <Group justify="space-between" h="100%" w="100%">
          <Group h="100%" gap={0} visibleFrom="sm">
            <Link to="/" className={classes.link}>
              Hem
            </Link>
            <Menu trigger="hover" transitionProps={{ exitDuration: 0 }} withinPortal withArrow offset={1}>
              <Menu.Target>
                <Link
                  to="/municipalities"
                  className={`${classes.link} ${location.startsWith("/municipalities") ? classes.active : ""}`}
                >
                  Kommunvis
                </Link>
              </Menu.Target>
              <Menu.Dropdown>
                <Menu.Item
                  component={Link}
                  to="/municipalities"
                  leftSection={<IconTable style={{ width: rem(14), height: rem(14) }} />}
                  className={location === "/municipalities" ? classes.menuActive : ""}
                >
                  Tabell
                </Menu.Item>
                <Menu.Item
                  component={Link}
                  to="/municipalities/map"
                  leftSection={<IconMap style={{ width: rem(14), height: rem(14) }} />}
                  className={location === "/municipalities/map" ? classes.menuActive : ""}
                >
                  Karta
                </Menu.Item>
              </Menu.Dropdown>
            </Menu>
            <Link
              to="/deviations"
              className={`${classes.link} ${location.startsWith("/deviations") ? classes.active : ""}`}
            >
              Avvikelser
            </Link>
            <Link
              to="/datasets"
              className={`${classes.link} ${location.startsWith("/datasets") ? classes.active : ""}`}
            >
              Datakällor
            </Link>
            <Link
              to="/system/status"
              className={`${classes.link} ${location.startsWith("/system/status") ? classes.active : ""}`}
            >
              Systemstatus
            </Link>
          </Group>

          <Group visibleFrom="sm">
            <Button variant="default" display="none">
              Logga in
            </Button>
          </Group>
        </Group>
      </AppShell.Header>

      <AppShell.Navbar p="md">
        <Link to="/" className={classes.link}>
          Hem
        </Link>
        <Menu
          trigger="hover"
          transitionProps={{ exitDuration: 0 }}
          withinPortal
          withArrow
          position="right"
          offset={-100}
        >
          <Menu.Target>
            <Link
              to="/municipalities"
              className={`${classes.link} ${location.startsWith("/municipalities") ? classes.active : ""}`}
            >
              Kommunvis
            </Link>
          </Menu.Target>
          <Menu.Dropdown>
            <Menu.Item
              component={Link}
              to="/municipalities"
              leftSection={<IconTable style={{ width: rem(14), height: rem(14) }} />}
              className={location === "/municipalities" ? classes.menuActive : ""}
            >
              Tabell
            </Menu.Item>
            <Menu.Item
              component={Link}
              to="/municipalities/map"
              leftSection={<IconMap style={{ width: rem(14), height: rem(14) }} />}
              className={location === "/municipalities/map" ? classes.menuActive : ""}
            >
              Karta
            </Menu.Item>
          </Menu.Dropdown>
        </Menu>
        <Link
          to="/deviations"
          className={`${classes.link} ${location.startsWith("/deviations") ? classes.active : ""}`}
        >
          Avvikelser
        </Link>
        <Link to="/datasets" className={`${classes.link} ${location.startsWith("/datasets") ? classes.active : ""}`}>
          Datakällor
        </Link>
        <Link
          to="/system/status"
          className={`${classes.link} ${location.startsWith("/system/status") ? classes.active : ""}`}
        >
          Systemstatus
        </Link>
        <Button variant="default" display="none">
          Logga in
        </Button>
      </AppShell.Navbar>

      <AppShell.Main style={{ display: "flex", alignItems: "stretch" }}>
        <Suspense
          fallback={
            <Flex align="center" justify="center" w="100%">
              <Loader size="xl" type="dots" />
            </Flex>
          }
        >
          <QueryErrorResetBoundary>
            {({ reset }) => (
              <ErrorBoundary
                onReset={reset}
                fallbackRender={({ resetErrorBoundary, error }) => (
                  <Alert variant="filled" color="red" icon={<IconExclamationCircle />} w="100%">
                    <p style={{ marginTop: 0 }}>
                      {"message" in error ? error.message : typeof error === "string" ? error : "Något gick fel"}
                    </p>
                    <Button onClick={() => resetErrorBoundary()} color="red" variant="white">
                      Försök igen
                    </Button>
                  </Alert>
                )}
              >
                <Switch>
                  <Route path="/municipalities/map" component={MunicipalitiesMapPage} />
                  <Route path="/municipalities/:code" component={MunicipalityPage} />
                  <Route path="/municipalities" component={MunicipalitiesPage} />
                  <Route path="/datasets/:id" component={DatasetPage} />
                  <Route path="/datasets" component={DatasetsPage} />
                  <Route path="/deviations/:id" component={DeviationPage} />
                  <Route path="/deviations" component={DeviationsPage} />
                  <Route path="/system/status" component={SystemStatus} />
                  <Route path="/" component={IndexPage} />
                </Switch>
              </ErrorBoundary>
            )}
          </QueryErrorResetBoundary>
        </Suspense>
      </AppShell.Main>
    </AppShell>
  );
};

export default App;
