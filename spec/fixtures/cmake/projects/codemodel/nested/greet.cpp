#include <cstdio>

namespace codemodel_greeting {

const char *text();

}

int main() {
  std::puts(codemodel_greeting::text());
  return 0;
}
