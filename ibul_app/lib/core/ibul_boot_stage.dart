/// Progressive web boot isolation stages (`IBUL_BOOT_STAGE` dart-define).
enum IbulBootStage {
  shell,
  providers,
  homeNoCache,
  normal,
}

IbulBootStage parseIbulBootStage(String? raw) {
  switch (raw?.trim().toLowerCase()) {
    case 'shell':
      return IbulBootStage.shell;
    case 'providers':
      return IbulBootStage.providers;
    case 'home_no_cache':
      return IbulBootStage.homeNoCache;
    case 'normal':
    default:
      return IbulBootStage.normal;
  }
}
