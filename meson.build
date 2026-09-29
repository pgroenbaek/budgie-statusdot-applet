project(
  'budgie-statusdot-applet',
  'vala',
  version: '1.0.0',
  default_options: ['warning_level=2']
)

prefix = get_option('prefix')
libdir = join_paths(prefix, get_option('libdir'))
budgielib = get_option('budgielib')
PLUGINS_INSTALL_DIR = join_paths(libdir, 'budgie-desktop', 'plugins', 'budgie-statusdot')

subdir('src')
subdir('data')