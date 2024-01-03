import { boundingExtent, getCenter } from "ol/extent";
import { fromLonLat } from "ol/proj";

export const swedenExtent = boundingExtent([fromLonLat([10.03, 54.96]), fromLonLat([24.17, 69.07])]);
export const swedenInitial = { center: getCenter(swedenExtent), zoom: 5 };
