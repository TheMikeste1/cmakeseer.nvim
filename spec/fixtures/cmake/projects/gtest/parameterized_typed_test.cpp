#include <gtest/gtest.h>

// TYPED_TEST_P (type-parameterized with instantiation prefix): two
// INSTANTIATE_TYPED_TEST_SUITE_P prefixes, three types, three tests each.
template <typename T> class TypedParamFixture : public ::testing::Test {};
TYPED_TEST_SUITE_P(TypedParamFixture);

TYPED_TEST_P(TypedParamFixture, TypedParamOne) { EXPECT_TRUE(true); }

TYPED_TEST_P(TypedParamFixture, TypedParamTwo) { EXPECT_EQ(0, TypeParam{}); }

REGISTER_TYPED_TEST_SUITE_P(TypedParamFixture, TypedParamOne, TypedParamTwo);

using TypedParamFixtureTypes = ::testing::Types<int, char, int>;
INSTANTIATE_TYPED_TEST_SUITE_P(TypedParamPrefix, TypedParamFixture,
                               TypedParamFixtureTypes);
INSTANTIATE_TYPED_TEST_SUITE_P(TypedParamPrefix2, TypedParamFixture,
                               TypedParamFixtureTypes);
