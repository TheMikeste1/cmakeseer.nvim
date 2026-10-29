#include <gtest/gtest.h>

#include <string>

// TEST_F (test fixture): two fixture classes, two tests each.
class BasicFixture : public ::testing::Test {
protected:
  void SetUp() override { value = 42; }

  int value = 0;
};

class OtherFixture : public ::testing::Test {
protected:
  std::string message = "hello";
};

TEST_F(BasicFixture, FixtureOnePasses) { EXPECT_EQ(42, value); }

TEST_F(BasicFixture, DISABLED_FixtureTwoIsSkipped) {
  FAIL() << "disabled tests only run with --gtest_also_run_disabled_tests";
}

TEST_F(OtherFixture, FixtureThreeChecksMessage) { EXPECT_EQ("hello", message); }

TEST_F(OtherFixture, FixtureFourFails) { EXPECT_EQ("goodbye", message); }
