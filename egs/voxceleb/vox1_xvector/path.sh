export KALDI_ROOT=`pwd`/../../..
export PATH=$PWD/utils/:$KALDI_ROOT/tools/openfst/bin:$KALDI_ROOT/tools/sph2pipe_v2.5:$PWD:$PATH
[ ! -f $KALDI_ROOT/tools/config/common_path.sh ] && echo >&2 "The standard file $KALDI_ROOT/tools/config/common_path.sh is not present -> Exit!" && exit 1
. $KALDI_ROOT/tools/config/common_path.sh
# 排序风格为c风格。排序后的文件可以在一些不支持 fseek()的流中——例如，含有管道的命令——提供类似
# 于随机存取查找的功能。需要Kaldi程序都会从其他Kaldi命令中读取多个管道流，读入各种不同类型的\
# 对象，然后对不同输入做一些类似于“合并然后排序”的处理。既然要合并排序，当然需要输入是经过排序的。
# 如果文件的排序方式会与C++排序字符串的方式不一样，Kaldi就会崩溃
export LC_ALL=C
