# NAME

Ini::Parser - simple INI files parser/reader with imports feature!

# VERSION

Version 0.1

# SYNOPSIS

    use Ini::Parser;

    # create object and feed with some data (optional)
    my $ini = Ini::Parser->new({ src => 'filename.ini', src_type => 'filename' });
    my $ini = Ini::Parser->new({ src => $filehandler, src_type => 'filehandler' });
    my $ini = Ini::Parser->new({ src => $obj_with_read_method, src_type => 'filenamobject' });
    my $ini = Ini::Parser->new({ src => $ini_in_string, src_type => 'string' });

    # feed with additional data
    $ini->feed('filename2.ini', { src_type => 'filename' });

    # parse when everything is loaded
    $ini->parse();

    # get all sections names
    $ini->sections();

    # get section data (Ini::Parse::Section)
    $ini->section('name');

    # get key from section
    $ini->section('name')->get('key');

    # whole config in single hash
    my %options = $ini->to_hash();

    # all keys names from single section
    my @keys = $ini->section('name')->keys()

    # all values from single section
    my @values = $ini->section('name')->values()

    # whole section data in single hash
    my %section = $ini->section('name')->to_hash();

# DESCRIPTION

Ini::Parser provides simple parser to .ini files. Syntax which is supported:

    [section name]
    key1 = value
    "key2" = value
    key2 = "value"
    key3 = "multi
    line
    value"

    [section2]
    [section3 name]
    key4 = value4
    "key name = with equal" = value5

    !import = somefile.ini

    [section4]
    key5 = value5
    key6 = "${section1.key2} ${key7} ${section5.key8}"
    key7 = value7
    [section5]
    key8 = value8

## SECTION

Section name can contain characters: a-z, A-Z, 0-9, ':', ' ', '!', '\_', '-'
and must have at least one characters length.

If `ci_sections` argument is provided to constructor, sections are always lowercased.

## KEY

Key can have two different syntaxes:
1\. Without quotes. Must begin with one of: a-z, A-Z, 0-9, ':', '\_', '-',
and further can contain characters: a-z, A-Z, 0-9, ':', '!', '\_', '-'
and must have at least one characters length.

2\. With quotes. Must begin and end with double quotes char, and contain
characters: a-z, A-Z, 0-9, ':', '!', ' ', '=', '\_', '-'

If `ci_keys` argument is provided to constructor, keys are always lowercased.

## VALUE

Value can contain almost any character. Also have two forms:

1\. Without quotes. There can be any character but without new line character.

2\. With quotes. There can be any character without double quote character
(new line character is allowed).

## DIRECTIVES

### IMPORT

Currently the only directive is recognized it's import. It import other .ini
file. Imported file override/join to currently parsed data.

For example:

if in host.ini we have:

    [section1]
    key1 = value1
    key2 = value2

    !import = guest.ini

    [section2]
    key4 = value4

and in guest.ini:

    [section1]
    key1 = new_value1
    key3 = value3

    [section3]
    key5 = value5

After parse we have:

    {
        section1 => {
            key1 => 'new_value1',
            key2 => 'value2',
            key3 => 'value3',
        },
        section2 => {
            key4 => 'value4'
        },
        section3 => {
            key5 => 'value5'
        }
    }

Files are parsed sequentially, so first statement will be overridden by next.
The same concerns `import` directive. In previous example, parser find _section1_,
locate keys _key1_ and _key2_, next find `import` directive. Parser
now parses imported file (here: _guest.ini_). Merge currently parsed content with
imported file, and returns to parsing next data from _host.ini_.

# EXPORT

There is no items exported. Module just provide class Ini::Parser.

# SUBROUTINES

## Class Ini::Parser

### Ini::Parser::new

Create new instance.

#### Arguments

- `cfg` (ref. HASH) \[opt\]
    - `src` - (STRING|OBJECT|GLOB) \[opt\]

        see: ["Ini::Parser::feed"](#Ini::Parser::feed)

    - `src_type` - (STRING) \[opt\]

        see: ["Ini::Parser::feed"](#Ini::Parser::feed)

    - `interpolate` - (BOOL) \[opt\]

        Enable or disable variables interpolation. Defaults to true.

    - `property_access` - (BOOL) \[opt\]

        Enable or disable property access to data. Defaults to false.

        If true, there will be enabled second way to access for data. Recommended is the one with implicit getters:

    - `ci_sections` - (BOOL) \[opt\]

        If false, sections are always lowercased, and case insensitive when search for it. Defaults to true.

    - `ci_keys` - (BOOL) \[opt\]

        If false, keys are always lowercased, and case insensitive when search for it. Defaults to true.

        - ["Ini::Parser::section"](#Ini::Parser::section)
        - ["Ini::Parser::Section::key"](#Ini::Parser::Section::key)

        But sometimes it's convenient to use properties:

            my $value = $ini->section_name->key_name;

        It's works only for sections and keys which name doesn't conflict with builtin methods name, and matching
        pattern:
            \[a-zA-Z\_\]\[a-zA-Z0-9\_\]\*

        For any other identifier there is only getter access.

#### Returns

- [Ini::Parser](#Class Ini::Parser) instance.

### Ini::Parser::feed

Feed [Ini::Parser](#Class Ini::Parser) with data to parse.

#### Arguments

- `src` - (STRING|OBJECT|GLOB) \[opt\]

    data to feed

- `cfg` - (ref. HASH) \[opt\]

    additional config

    - `src_type` - (STRING) \[opt\]

        If not given, will try to guest what to do with `src`. One of:

        - `string` - `src` is just string to parse
        - `object` - `src` is object with method `read`
        - `filename` - `src` is path to file where data is stored
        - `filehandler` - `src` is opened file handler

#### Returns

- `self` instance.

### Ini::Parser::parse

Parse all feeded sources.

#### Arguments

- __NONE__

#### Returns

- `self` instance.

### Ini::Parser::merge

Merge given data with current one.

#### Arguments

- `src` - (ref. HASH|Ini::Parser)

    New data to merge into current instance. If Ini::Parser instance is given,
    we call ["Ini::Parser::to\_hash"](#Ini::Parser::to\_hash) first.

- `dst` - (STRING) \[opt\]

    import `src` into section `dst`. If given, assume that `src` is `dst`
    section content. If missing, assume that `src` is set of sections and
    their content.

#### Returns

- `self` instance.

### Ini::Parser::section

Return whole section data.

#### Arguments

- `section` - (STRING)

    Name of section from file.

#### Returns

- [Ini::Parser::Section](#Class Ini::Parser::Section) instance. See below.

### Ini::Parser::sections

Returns list of sections names.

#### Arguments

- __NONE__

#### Returns

- (ARRAY of STRING)

    Array of section names from parsed sources.

### Ini::Parser::is\_parsed

Check for existent of parsed data.

Raise exception [Ini::Parser::Error](#Class Ini::Parser::Error) if source is not parsed yet.

#### Arguments

- __NONE__

#### Returns

- (BOOL)

    Always true.

### Ini::Parser::to\_hash

Return all parsed structure as HASH.

#### Arguments

- __NONE__

#### Returns

- (HASH)

    Parsed data.

### Ini::Parser::process\_instruction

For internal use.

Dispatch found directives to specific callbacks.

When call, try to find method `Ini::Parser::__process_instruction__ . INSTRUCTION_NAME`, and call it.
In other case, raise [Ini::Parser::Error](#Class Ini::Parser::Error) exception.

#### Arguments

- instruction - (STRING)

    Instruction name.

- value - (STRING)

    Value of directive from .ini file. For example if in .ini file is directive:

        !import = guest.ini

    'guest.ini' is value for directive `import`.

#### Returns

- `self` instance.

### Ini::Parser::MAX\_FEED\_FILENAME\_LENGTH

For internal use.

Constant that helps for guessing when given for ["Ini::Parser::feed"](#Ini::Parser::feed) string is file name or data to parse.

## Class Ini::Parser::Section

### Ini::Parser::Section::new

Create instance of class.

#### Arguments

- section - (STRING)

    Section name.

- data - (ref. HASH)

    Section data.

#### Returns

- [Ini::Parser::Section](#Class Ini::Parser::Section) instance

### Ini::Parser::Section::get

Return single key from section data.

Raise [Ini::Parser::Error](#Class Ini::Parser::Error) exception if key is not found, unless `default`
argument is given.

#### Arguments

- key - (STRING)

    Key name.

- default - (MISC) \[opt\]

    Default value to return if `key` is not found.

#### Returns

- (STRING)

    Value

### Ini::Parser::Section::keys

Returns list of all keys from this section.

Keys are always sorted.

#### Arguments

- __NONE__

#### Returns

- (ARRAY of STRING)

    List of keys from this section.

### Ini::Parser::Section::values

Returns list of all values from this section.

Order of values is always matching to order of keys read via ["Ini::Parser::Section::keys"](#Ini::Parser::Section::keys).

#### Arguments

- __NONE__

#### Returns

- (ARRAY of STRING)

    List of values from this section.

### Ini::Parser::Section::to\_hash

Return all section data as HASH.

#### Arguments

- __NONE__

#### Returns

- (HASH)

    Section data.

## Class Ini::Parser::Error

### Ini::Parser::Error::new

Create new instance.

#### Arguments

- msg - (STRING)

    Error message.

- code - (INT)

    Error code.

#### Returns

- [Ini::Parser::Error](#Class Ini::Parser::Error) instance.

### Ini::Parser::Error::message

Returns error message.

#### Arguments

- __NONE__

#### Returns

- (STRING)

    Error message.

### Ini::Parser::Error::msg

Alias to ["Ini::Parser::Error::message"](#Ini::Parser::Error::message).

### Ini::Parser::Error::code

Returns error code.

#### Arguments

- __NONE__

#### Returns

- (STRING)

    Error code.

### Ini::Parser::Error::to\_string

Returns string representation of exception.

#### Arguments

- __NONE__

#### Returns

- (STRING)

    String representation of exception.

# SEE ALSO

- Other .ini or config parsers

    [Config::Tiny](http://search.cpan.org/perldoc?Config::Tiny), [Config::Simple](http://search.cpan.org/perldoc?Config::Simple), [Config::General](http://search.cpan.org/perldoc?Config::General)

- [Try::Tiny::SmartCatch](http://search.cpan.org/perldoc?Try::Tiny::SmartCatch)

# AUTHOR

Marcin Sztolcman, `<marcin at urzenia.net>`

# BUGS

Please report any bugs or feature requests through the web interface at
[http://github.com/mysz/ini-parser/issues](http://github.com/mysz/ini-parser/issues).

# SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Ini::Parser

You can also look for information at:

- Ini::Parser home & source code

    [http://github.com/mysz/ini-parser](http://github.com/mysz/ini-parser)

- Issue tracker (report bugs here)

    [http://github.com/mysz/ini-parser/issues](http://github.com/mysz/ini-parser/issues)

- Search CPAN

    [http://search.cpan.org/dist/ini-parser/](http://search.cpan.org/dist/ini-parser/)

# LICENSE AND COPYRIGHT

    Copyright (c) 2013 Marcin Sztolcman. All rights reserved.

    This program is free software; you can redistribute
    it and/or modify it under the terms of the MIT license.
