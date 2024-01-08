import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App.tsx";
import { queryClient } from "./queryClient.ts";
import { MantineProvider } from "@mantine/core";
import { QueryClientProvider } from "@tanstack/react-query";
import { QueryParamAdapter, QueryParamAdapterComponent, QueryParamProvider } from "use-query-params";
import { Router, useLocation } from "wouter";
import queryString from "query-string";
import { useSearch } from "wouter/use-location";
import proj4 from "proj4";
import { register } from "ol/proj/proj4";

import "@mantine/notifications/styles.css";
import "./index.css";
import { Notifications } from "@mantine/notifications";

proj4.defs("EPSG:3006", "+proj=utm +zone=33 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs +type=crs");
register(proj4);

export const WouterAdapter: QueryParamAdapterComponent = ({ children }) => {
  const [_loc, navigate] = useLocation();
  const search = useSearch();

  const adapter: QueryParamAdapter = {
    replace(location) {
      navigate(location.search || "?", {
        replace: true,
      });
    },
    push(location) {
      navigate(location.search || "?", {
        replace: false,
      });
    },
    get location() {
      return { search };
    },
  };

  return children(adapter);
};

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <MantineProvider>
      <Notifications />
      <QueryClientProvider client={queryClient}>
        <Router>
          <QueryParamProvider
            adapter={WouterAdapter}
            options={{
              searchStringToObject: queryString.parse,
              objectToSearchString: queryString.stringify,
            }}
          >
            <App />
          </QueryParamProvider>
        </Router>
      </QueryClientProvider>
    </MantineProvider>
  </React.StrictMode>,
);
