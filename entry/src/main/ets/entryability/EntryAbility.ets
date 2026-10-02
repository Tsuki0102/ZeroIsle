import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window, font } from '@kit.ArkUI';
import { emitter } from '@kit.BasicServicesKit';
import { preferences } from '@kit.ArkData';
import { setCardNavTarget, EVT_CARD_NAV } from '../common/Common';
import { DistributedSync } from '../service/DistributedSync';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  /** 启动时应用持久化的外观设置(D1):色彩模式 + 状态栏 + 图表暗色开关 */
  private applyTheme(): string {
    let mode: string = 'system';
    try {
      const pref = preferences.getPreferencesSync(this.context, { name: 'zeroisle_settings' });
      mode = pref.getSync('colorMode', 'system') as string;
    } catch (err) {
      mode = 'system';
    }
    if (mode === 'dark') {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
    } else if (mode === 'light') {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
    } else {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    }
    return mode;
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'ZeroIsleAbility', '%{public}s', 'Ability onCreate');
    // 冷启动:桌面卡片点击目标暂存,Index 首页就绪后消费
    this.handleCardWant(want, false);
    // 启动超级终端分布式同步(同账号多设备自动汇聚碳账本);环境不支持时内部优雅降级
    DistributedSync.init(this.context);
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 热启动:广播给已就绪的首页
    this.handleCardWant(want, true);
  }

  private handleCardWant(want: Want, emit: boolean): void {
    const target = want.parameters?.['target'] as string | undefined;
    if (target !== undefined && target !== '') {
      setCardNavTarget(target);
      if (emit) {
        emitter.emit({ eventId: EVT_CARD_NAV }, {});
      }
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'ZeroIsleAbility', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'ZeroIsleAbility', '%{public}s', 'Ability onWindowStageCreate');

    // 冷启动恢复持久化主题(D1):否则重启会回到跟随系统,深色丢失
    let themeMode: string = 'system';
    try {
      const pref = preferences.getPreferencesSync(this.context, { name: 'zeroisle_settings' });
      themeMode = pref.getSync('colorMode', 'system') as string;
    } catch (err) {
      themeMode = 'system';
    }
    AppStorage.setOrCreate('darkOn', themeMode === 'dark');

    // 注册 Nunito 数字展示字体(碳账数字识别符号)
    try {
      font.registerFont({ familyName: 'NunitoDisplay', familySrc: $rawfile('fonts/Nunito-ExtraBold.ttf') });
      font.registerFont({ familyName: 'NunitoBlack', familySrc: $rawfile('fonts/Nunito-Black.ttf') });
    } catch (err) {
      hilog.error(DOMAIN, 'ZeroIsleAbility', 'Failed to register fonts. Cause: %{public}s', JSON.stringify(err));
    }

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'ZeroIsleAbility', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'ZeroIsleAbility', 'Succeeded in loading the content.');
      // 状态栏文字颜色随外观模式联动(D1)
      const mode: string = this.applyTheme();
      try {
        const mainWin = windowStage.getMainWindowSync();
        // 窗口底色随主题联动,避免深色下状态栏区露白
        mainWin.setWindowBackgroundColor(mode === 'dark' ? '#0C1512' : '#F4F8F6');
        mainWin.setWindowSystemBarProperties({
          statusBarColor: 'rgba(0,0,0,0)',
          statusBarContentColor: mode === 'dark' ? '#E8F1EC' : '#0F172A'
        });
      } catch (err2) {
        hilog.error(DOMAIN, 'ZeroIsleAbility', 'Failed to set status bar. Cause: %{public}s', JSON.stringify(err2));
      }
    });

  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'ZeroIsleAbility', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'ZeroIsleAbility', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'ZeroIsleAbility', '%{public}s', 'Ability onBackground');
  }
}