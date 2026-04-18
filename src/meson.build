# Statusdot Applet build
budgie_dep = dependency('budgie-1.0', required: true)
gtk_dep = dependency('gtk+-3.0')
glib_dep = dependency('glib-2.0')
gettext_dep = dependency('gettext', required: false)
json_glib_dep = dependency('json-glib-1.0', required: true)
soup_dep = dependency('libsoup-2.4', required: true)
secret_dep = dependency('libsecret-1', required: true)

applet_statusdot_sources = [
  'StatusDotAPI.vala',
  'StatusDotData.vala',
  'StatusDotManager.vala',
  'StatusDotApplet.vala',
  'StatusDotSettings.vala',
  'StatusDotWindow.vala',
]

applet_statusdot_deps = [
  budgie_dep,
  gtk_dep,
  glib_dep,
  gettext_dep,
  json_glib_dep,
  soup_dep,
  secret_dep,
]

add_project_arguments(
  '-DGETTEXT_PACKAGE="budgie-statusdot-applet"',
  language: 'c'
)

shared_library('statusdotapplet',
  applet_statusdot_sources,
  dependencies: applet_statusdot_deps,
  install: true
)
