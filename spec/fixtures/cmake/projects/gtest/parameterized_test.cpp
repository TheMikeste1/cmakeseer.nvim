#include <gtest/gtest.h>

#include <string>

// TEST_P (value-parameterized): two INSTANTIATE_TEST_SUITE_P prefixes,
// two tests each, one disabled test.
class IntParamFixture : public ::testing::TestWithParam<int> {};
TEST_P(IntParamFixture, IntOne) { EXPECT_GE(GetParam(), 0); }
TEST_P(IntParamFixture, IntTwo) { EXPECT_LT(GetParam(), 100); }
TEST_P(IntParamFixture, DISABLED_IntThreeIsSkipped) {
  FAIL() << "disabled tests only run with --gtest_also_run_disabled_tests";
}
INSTANTIATE_TEST_SUITE_P(IntPrefix, IntParamFixture,
                         ::testing::Values(1, 2, 3));
INSTANTIATE_TEST_SUITE_P(IntPrefix2, IntParamFixture,
                         ::testing::Values(7, 8, 9));

class StringParamFixture : public ::testing::TestWithParam<std::string> {};
TEST_P(StringParamFixture, StringOne) { EXPECT_FALSE(GetParam().empty()); }
TEST_P(StringParamFixture, StringTwo) { EXPECT_EQ(2, GetParam().size()); }
INSTANTIATE_TEST_SUITE_P(StringPrefix, StringParamFixture,
                         ::testing::Values("ab", "cd"));
