import localUnitTest from './LocalUnit.test';
import zeroIsleLogicTest from './ZeroIsleLogic.test';

export default function testsuite() {
  localUnitTest();
  zeroIsleLogicTest();
}