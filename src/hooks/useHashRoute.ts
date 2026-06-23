import { useEffect, useState } from "react";

const DEFAULT_ROUTE = "/";

function readRoute() {
  const hash = window.location.hash.replace(/^#/, "");
  return hash || DEFAULT_ROUTE;
}

export function useHashRoute() {
  const [route, setRoute] = useState(readRoute);

  useEffect(() => {
    const onHashChange = () => setRoute(readRoute());
    window.addEventListener("hashchange", onHashChange);
    return () => window.removeEventListener("hashchange", onHashChange);
  }, []);

  return route;
}
