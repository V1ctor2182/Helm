import { mount } from 'svelte'
import './app.css'
import App from './App.svelte'
import { theme } from './lib/theme.svelte'

// Apply theme (data-theme + daily accent) before first paint.
theme.init()

const app = mount(App, {
  target: document.getElementById('app')!,
})

export default app
