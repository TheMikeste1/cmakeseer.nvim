#include <gtest/gtest.h>

// TYPED_TEST (type-parameterized): three types (int, char, int), two tests
// each.
template <typename T> class TypedFixture : public ::testing::Test {};

using TypedFixtureTypes = ::testing::Types<int, char, int>;
TYPED_TEST_SUITE(TypedFixture, TypedFixtureTypes);

TYPED_TEST(TypedFixture, TypedOne) { EXPECT_TRUE(true); }

TYPED_TEST(TypedFixture, TypedTwo) { EXPECT_EQ(0, TypeParam{}); }
