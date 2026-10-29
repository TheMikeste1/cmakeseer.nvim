#include <gtest/gtest.h>

// TEST (basic): two suites, two tests each.
TEST(BasicSuite, OnePasses) { EXPECT_EQ(1, 1); }

TEST(BasicSuite, TwoFails) { EXPECT_EQ(1, 2); }

TEST(OtherSuite, OnePasses) { EXPECT_TRUE(true); }

TEST(OtherSuite, DISABLED_TwoIsSkipped) {
  FAIL() << "disabled tests only run with --gtest_also_run_disabled_tests";
}
