#include <gtest/gtest.h>

#include <cstdlib>

// Second executable: distinct test content from gtest_all.
// Exercises death tests and suite-level SetUp/TearDown.

class DeathFixture : public ::testing::Test {
 protected:
  static void SetUpTestSuite() { counter = 0; }
  static void TearDownTestSuite() { counter = 0; }

  static int counter;
};

int DeathFixture::counter = 0;

TEST_F(DeathFixture, DeathTestExits) {
  EXPECT_DEATH_IF_SUPPORTED(exit(42), ".*");
}

TEST_F(DeathFixture, DeathTestMessage) {
  EXPECT_DEATH_IF_SUPPORTED(abort(), ".*");
}

TEST(SecondBasic, FirstPasses) {
  EXPECT_EQ(2, 1 + 1);
}

TEST(SecondBasic, SecondFails) {
  EXPECT_EQ(3, 1 + 1);
}

TEST_F(DeathFixture, ThirdPasses) {
  EXPECT_TRUE(true);
}

TEST_F(DeathFixture, FourthFails) {
  EXPECT_EQ(0, 1);
}
