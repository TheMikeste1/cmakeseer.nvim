#include <gtest/gtest.h>

// TEST located in a nested directory to exercise recursive source discovery.
TEST(NestedSuite, OnePasses) {
  EXPECT_TRUE(true);
}

TEST(NestedSuite, TwoFails) {
  EXPECT_EQ(1, 2);
}
