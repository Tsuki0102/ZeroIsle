/**
 * 统一动效 Token(页面转场时长)
 * 用法:在各 @Entry 页面 struct 内实现(PageTransitionEnter/Exit 必须在 pageTransition 方法内直接调用):
 *   pageTransition() {
 *     PageTransitionEnter({ duration: ZeroMotion.pageDurIn, curve: Curve.Friction }).opacity(0).translate({ y: 16 })
 *     PageTransitionExit({ duration: ZeroMotion.pageDurOut, curve: Curve.Friction }).opacity(0)
 *   }
 */
export class ZeroMotion {
  /** 进入(推入)时长 */
  static readonly pageDurIn: number = 260
  /** 退出(返回)时长 */
  static readonly pageDurOut: number = 140
  /** 应用进场(品牌启动层)淡出前停留时长 */
  static readonly splashHold: number = 950
  /** 进场层淡出时长 */
  static readonly splashOutDur: number = 680
}
