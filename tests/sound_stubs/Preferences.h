#pragma once
#include <map>
#include <string>
#include <cstdint>
class Preferences {
 public:
  inline static std::map<std::string,uint8_t> values;
  inline static bool fail=false;
  inline static std::map<std::string,uint32_t> words;
  inline static bool fail_word=false;
  bool begin(const char*,bool){return !fail;}
  void end(){}
  uint8_t getUChar(const char* key,uint8_t fallback){auto i=values.find(key);return i==values.end()?fallback:i->second;}
  bool getBool(const char* key,bool fallback){return getUChar(key,fallback)!=0;}
  uint32_t getUInt(const char* key,uint32_t fallback){auto i=words.find(key);return i==words.end()?fallback:i->second;}
  unsigned putUInt(const char* key,uint32_t value){if(fail||fail_word)return 0;words[key]=value;return 4;}
  unsigned putUChar(const char* key,uint8_t v){if(fail)return 0;values[key]=v;return 1;}
  unsigned putBool(const char* key,bool v){return putUChar(key,v);}
  bool clear(){values.clear();words.clear();return true;}
};
