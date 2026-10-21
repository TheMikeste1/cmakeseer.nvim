#include "codemodel_example/version.hpp"
#include "config.hpp"
#include "math.hpp"

int main() {
  return codemodel_math::answer() == codemodel_example::version() ? 0 : 1;
}
