use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Ini::Parser',
    AUTHOR              => q{Marcin Sztolcman <marcin@urzenia.net>},
    VERSION_FROM        => 'lib/Ini/Parser.pm',
    ABSTRACT_FROM       => 'lib/Ini/Parser.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'MIT')
      : ()),
    PL_FILES            => {},
    MIN_PERL_VERSION    => '5.006',
    PREREQ_PM => {
        'Test::More' => 0,
        'Try::Tiny::SmartCatch' => "0.5",
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Ini-Parser-*' },
    META_MERGE        => {
        resources => {
            repository  =>  'https://github.com/mysz/ini-parser',
        },
    },
);
