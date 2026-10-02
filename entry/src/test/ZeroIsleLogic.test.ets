import { describe, it, expect } from '@ohos/hypium';
import { SemanticParser } from '../main/ets/service/SemanticParser';
import { FactorLibrary } from '../main/ets/data/FactorLibrary';
import { csvField } from '../main/ets/common/TextUtil';
import { ISLAND_STAGES, POINTS_PER_KG } from '../main/ets/model/Models';

/**
 * 零屿纯逻辑单测(E8):语义解析 / 因子库 / CSV 转义 / 模型常量
 * 运行:DevEco Studio 测试面板「Local」或 CLI test 任务
 */
export default function zeroIsleLogicTest() {
  describe('zeroIsleLogic', () => {
    it('parses_compound_sentence', 0, () => {
      const r = SemanticParser.parse('骑车3公里,午餐光盘');
      expect(r.items.length).assertEqual(2);
      expect(r.items[0].factorId).assertEqual('T01');
      expect(r.items[0].amount).assertEqual(3);
      expect(r.items[1].factorId).assertEqual('F01');
      expect(r.items[1].amount).assertEqual(1);
    });

    it('computes_co2_and_points', 0, () => {
      const r = SemanticParser.parse('节电2度');
      expect(r.items.length).assertEqual(1);
      expect(r.items[0].factorId).assertEqual('E01');
      const co2: number = 2 * FactorLibrary.byId('E01').factor;
      expect(Math.abs(r.items[0].co2Kg - co2) < 0.0001).assertTrue();
      expect(r.items[0].points).assertEqual(Math.round(co2 * POINTS_PER_KG));
    });

    it('rejects_unknown_text', 0, () => {
      const r = SemanticParser.parse('今天天气不错');
      expect(r.items.length).assertEqual(0);
      expect(r.unmatched.length).assertEqual(1);
    });

    it('factor_library_lookup', 0, () => {
      expect(FactorLibrary.byId('E01').factor).assertEqual(0.57);
      expect(FactorLibrary.categoryOf('T01')).assertEqual('travel');
      expect(FactorLibrary.categoryName('travel')).assertEqual('绿色出行');
      expect(FactorLibrary.categoryName('nope')).assertEqual('nope');
      expect(FactorLibrary.factors.length).assertEqual(30);
    });

    it('points_rule_1kg_10coins', 0, () => {
      expect(POINTS_PER_KG).assertEqual(10);
      const f = FactorLibrary.byId('T01');
      expect(Math.round(3 * f.factor * POINTS_PER_KG)).assertEqual(6);
    });

    it('csv_escapes_quotes_commas_newlines', 0, () => {
      expect(csvField('普通字段')).assertEqual('普通字段');
      expect(csvField('含,逗号')).assertEqual('"含,逗号"');
      expect(csvField('含"引号')).assertEqual('"含""引号"');
      expect(csvField('含\n换行')).assertEqual('"含\n换行"');
    });

    it('stage_thresholds_monotonic', 0, () => {
      expect(ISLAND_STAGES.length).assertEqual(5);
      for (let i = 1; i < ISLAND_STAGES.length; i++) {
        expect(ISLAND_STAGES[i].thresholdKg > ISLAND_STAGES[i - 1].thresholdKg).assertTrue();
      }
    });
  });
}
