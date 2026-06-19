// "Current project" context (F8 §6). The shell tracks one active project;
// Chat / research / agent / records read `projects.current` to attach to it.
// The cockpit Room populates `recent` and drives selection — m5 ships the
// store + the seam; the list is empty until then.

export interface Project {
  path: string
  name: string
}

export class ProjectStore {
  current = $state<Project | null>(null)
  recent = $state<Project[]>([])

  setCurrent(p: Project | null): void {
    this.current = p
  }

  /** cockpit Room wires recent-projects here. */
  setRecent(list: Project[]): void {
    this.recent = list
  }

  open(p: Project): void {
    this.setCurrent(p)
    this.recent = [p, ...this.recent.filter((x) => x.path !== p.path)]
  }
}

export const projects = new ProjectStore()
