import { FC, Suspense } from "react";

import { Burger, Button, Group, AppShell, Loader, Flex, Alert } from "@mantine/core";
import { Route, Switch } from "wouter";

import IndexPage from "./pages/index.tsx";
import MunicipalitiesPage from "./pages/municipalities.tsx";
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
import { IconExclamationCircle } from "@tabler/icons-react";

const App: FC = () => {
  const [opened, { toggle }] = useDisclosure(false);

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
            <a href="/" className={classes.link}>
              Hem
            </a>
            <a href="/municipalities" className={classes.link}>
              Kommunvis
            </a>
            <a href="/deviations" className={classes.link}>
              Avvikelser
            </a>
            <a href="/datasets" className={classes.link}>
              Datakällor
            </a>
          </Group>

          <Group visibleFrom="sm">
            <Button variant="default" display="none">
              Logga in
            </Button>
          </Group>
        </Group>
      </AppShell.Header>

      <AppShell.Navbar p="md">
        <a href="/" className={classes.link}>
          Hem
        </a>
        <a href="/municipalities" className={classes.link}>
          Kommunvis
        </a>
        <a href="/deviations" className={classes.link}>
          Avvikelser
        </a>
        <a href="/datasets" className={classes.link}>
          Datakällor
        </a>
        <Button variant="default">Logga in</Button>
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
                  <Route path="/municipalities/:code" component={MunicipalityPage} />
                  <Route path="/municipalities" component={MunicipalitiesPage} />
                  <Route path="/datasets/:id" component={DatasetPage} />
                  <Route path="/datasets" component={DatasetsPage} />
                  <Route path="/deviations/:id" component={DeviationPage} />
                  <Route path="/deviations" component={DeviationsPage} />
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
