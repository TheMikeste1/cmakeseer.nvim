#include <gtest/gtest.h>

// Second nested test file in a nested directory.
TEST(SecondNested, OnePasses) {
  EXPECT_TRUE(true);
}

TEST(SecondNested, TwoFails) {
  EXPECT_EQ(1, 2);
}
