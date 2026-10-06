// True when an event from the server-wide V2 event stream belongs to this
// plugin instance's location. V1 plugins only received project-scoped events;
// the V2 stream spans every location the server serves, so each consumer
// filters before acting. Events without location data are processed, matching
// V1's coverage for shapes that carry no location.
import { realpathSync } from "node:fs";
import { resolve } from "node:path";

export function eventMatchesRoot(event, root) {
  if (!root) return false;
  const directory = event?.location?.directory ?? event?.data?.location?.directory;
  if (!directory) return true;
  let eventPath = directory;
  let rootPath = root;
  try {
    eventPath = realpathSync(directory);
  } catch {
    eventPath = resolve(directory);
  }
  try {
    rootPath = realpathSync(root);
  } catch {
    rootPath = resolve(root);
  }
  return eventPath === rootPath;
}
