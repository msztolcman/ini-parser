package Ini::Parser;
{
    use 5.006;
    use strict;
    use warnings;

    use vars qw/$VERSION/;
    $VERSION = '0.1';

    use Scalar::Util qw/blessed/;

    use Try::Tiny::SmartCatch 0.5 qw/:all/;

    sub MAX_FEED_FILENAME_LENGTH () { 256 }

    # regular expressions
    my $_rxp_section__chars = '[a-zA-Z0-9: !_-]+';
    my $rxp_section = qr/
        (?:^|\r?\n)+
        [ \t]*
        \[
            ($_rxp_section__chars)
        \]
        [ \t]*
        (?=\r?\n|$)
    /x;

    my $_rxp_data__normal_key = '[a-zA-Z0-9:_-][a-zA-Z0-9:!_-]*';
    my $_rxp_data__quoted_key = '"[a-zA-Z0-9:! =_-]+"';
    my $_rxp_data__instruction = '![a-zA-Z0-9:!_-]+';
    my $_rxp_data__quoted_value = '"([^"]*)"';
    my $_rxp_data__normal_value = '([^;\r\n]*)';
    my $rxp_data = qr/
        (?:
            (?:
                [ \t]*
                (?:
                    ($_rxp_data__normal_key)    # normal key name
                    |
                    ($_rxp_data__quoted_key)    # quoted key name
                    |
                    ($_rxp_data__instruction)   # instruction
                )
                [ \t]*
                =
                [ \t]*
                (?:
                    $_rxp_data__quoted_value
                    |
                    $_rxp_data__normal_value
                )?
                [ \t]*
                (?:;.*)?
                (?:\r?\n|$)+
            )
            |
            (?:\r?\n|$)+
        )
    /x;

    my $rxp_interpolate = qr/
        (
            \$
            \{
                (?:
                    ($_rxp_section__chars)\.
                )?
                (?:
                    ($_rxp_data__normal_key)
                    |
                    ($_rxp_data__quoted_key)
                )
            \}
        )
    /x;

    sub __trim {
        my($s) = @_;

        $s =~ s/^\s+//;
        $s =~ s/\s+$//;

        return $s;
    }

    sub new {
        my($class, $cfg) = @_;

        my($ci_keys, $ci_sections, $interpolate, $property_access, $self);

        $ci_keys = (exists($$cfg{ci_keys}) ? $$cfg{ci_keys} : 1);
        $ci_sections = (exists($$cfg{ci_sections}) ? $$cfg{ci_sections} : 1);
        $interpolate = (exists($$cfg{interpolate}) ? $$cfg{interpolate} : 1);
        $property_access = (exists($$cfg{property_access}) ? $$cfg{property_access} : 0);
        $self = {
            source => [],
            parsed => undef,
            interpolate => ($interpolate ? 1 : 0),
            property_access => ($property_access ? 1 : 0),
            ci_keys => ($ci_keys ? 1 : 0),
            ci_sections => ($ci_sections ? 1 : 0),
        };

        $self = bless($self, $class);

        $self->feed($$cfg{src}, { src_type => $$cfg{src_type} })
            if (defined($$cfg{src}));

        return $self;
    }

    sub __feed__filename {
        my($self, $filename) = @_;

        local($!);
        my($data, $fh);
        if (!open($fh, '<', $filename) || !defined(sysread($fh, $data, -s $fh, 0))) {
            close($fh) if ($fh);
            throw(Ini::Parser::Error->new("Cannot open file \"$filename\" to read: $!", $! + 0));
        }

        close($fh);

        push(@{$$self{source}}, $data);

        return $self;
    }

    sub __feed__handler {
        my($self, $fh) = @_;

        local($!);
        my($data);
        if (!defined(sysread($fh, $data, -s $fh, 0))) {
            throw(Ini::Parser::Error->new("Cannot read from handler: $!", $! + 0));
        }

        push(@{$$self{source}}, $data);

        return $self;
    }

    sub __feed__string {
        my($self, $src) = @_;

        push(@{$$self{source}}, $src);

        return $self;
    }

    sub __feed__object {
        my($self, $obj) = @_;

        push(@{$$self{source}}, $obj->read());

        return $self;
    }

    sub feed {
        my($self, $src, $cfg) = @_;

        $cfg = {}
            if (!defined($src));

        my($callback, $src_type);
        if (!exists($$cfg{src_type}) || !defined($$cfg{src_type}) || !length($$cfg{src_type})) {
            if (blessed($src) && $src->can('read')) {
                $src_type = 'object';
            }
            elsif (ref($src) eq 'GLOB') {
                $src_type = 'handler';
            }
            elsif (!ref($src)) {
                if (length($src) && length($src) < MAX_FEED_FILENAME_LENGTH && index($src, "\n") < 0) {
                    $src_type = 'filename';
                }
                else {
                    $src_type = 'string';
                }
            }
        }
        else {
            $src_type = $$cfg{src_type};
        }

        $src_type = ''
            if (!defined($src_type));

        $callback = $self->can('__feed__' . $src_type);

        throw(Ini::Parser::Error->new ("Unrecognized source type: " . ref($src)))
            if (!defined($callback));

        return $self->$callback($src);
    }

    sub __process_instruction__import {
        my($self, $instruction, $value) = @_;

        $value = __trim ($value);

        throw(Ini::Parser::Error->new(qq/Unknown file "$value" in !import/))
            if (!-f $value);

        my $data = __PACKAGE__->new({src => $value, src_type => 'filename'});
        $data->parse();
        $self->merge($data);

        return $self;
    }

    sub process_instruction {
        my($self, $instruction, $value) = @_;

        my($callback);
        if ($instruction !~ s/^!// || !($callback = $self->can('__process_instruction__' . $instruction))) {
            throw(Ini::Parser::Error->new('Unknown instruction: ' . $instruction));
        }

        return $self->$callback($instruction, $value);
    }

    sub __parse__simple {
        my($self) = @_;

        my($data, $i, $i_max, $key, @parts, $section, $src, $value);

        foreach $src (@{$$self{source}}) {
            @parts = split(/$rxp_section/, __trim($src));
            $i_max = @parts;

            for ($i = 1; $i < $i_max; $i += 2) {
                ($section, $data) = map {
                    defined($_) ? __trim($_) : ''
                } @parts[$i, $i+1];

                $section = lc ($section) if ($$self{ci_sections});
                $$self{parsed}{$section} = {}
                    if (!defined($$self{parsed}{$section}));

                while ($data =~ /$rxp_data/g) {
                    $value = (defined($4) ? $4 : $5);

                    if (defined($3)) {
                        $self->process_instruction($3, $value);
                    }
                    else {
                        $key = undef;
                        if (defined($1)) {
                            $key = $1;
                        }
                        elsif (defined($2)) {
                            $key = substr($2, 1, -1);
                        }

                        next if (!defined($key));

                        $key = lc ($key) if ($$self{ci_keys});
                        $$self{parsed}{$section}{$key} = $value;
                    }
                }
            }
        }

    }

    sub __parse__interpolation {
        my($self) = @_;

        my($key, $key_name, $section);
        #iterating thru keys - we don't want to automatically create Ini::Parser::Section objects
        foreach $section (keys(%{$$self{parsed}})) {
            foreach $key (keys(%{$$self{parsed}{$section}})) {
                $$self{parsed}{$section}{$key} =~ s/$rxp_interpolate/
                    $key_name = (defined($4) ? substr($4, 1, -1) : $3);
                    defined($key_name) && defined($2)   ? $$self{parsed}{$2}{$key_name}         :
                    defined($key_name)                  ? $$self{parsed}{$section}{$key_name}   :
                                                          $1
                /ge;
            }
        }
    }

    my %property_access_disallow = map { $_ => 1 } keys(%{__PACKAGE__::});
    my $rxp_property_access_allowed = qr/^ [a-zA-Z_] [a-zA-Z0-9_]* $/x;
    sub __parse__property_access {
        my($self) = @_;

        #iterating thru keys - we don't want to automatically create Ini::Parser::Section objects
        foreach my $__section (keys(%{$$self{parsed}})) {
            next if ($property_access_disallow{$__section});
            next if ($__section !~ /$rxp_property_access_allowed/);

            my ($__sub, $__name);
            $__sub = sub {
                my($self) = @_;
                return $self->section($__section);
            };
            $__name = ref($self) . '::' . $__section;

            no strict 'refs';
            *{$__name} = $__sub;
        }
    }

    sub parse {
        my($self) = @_;

        $$self{parsed} = {}
            if (!defined($$self{parsed}));

        $self->__parse__simple ();
        $self->__parse__interpolation ()
            if ($$self{interpolate});

        $self->__parse__property_access()
            if ($$self{property_access});

        return $self;
    }

    sub merge {
        my($self, $src, $dst) = @_;

        $self->is_parsed();

        throw(Ini::Parser::Error->new('Unknown source type to merge: ' . ref($src)))
            if (ref($src) ne __PACKAGE__ && ref($src) ne 'HASH');

        $src = { $src->to_hash() }
            if (ref($src) eq __PACKAGE__);

        if (defined($dst)) {
            @{$$self{parsed}{$dst}}{keys(%$src)} = values(%$src);
        }
        else {
            foreach (keys(%$src)) {
                @{$$self{parsed}{$_}}{keys(%{$$src{$_}})} = values(%{$$src{$_}});
            }
        }

        return $self;
    }

    sub section {
        my($self, $section) = @_;

        $self->is_parsed();

        throw(Ini::Parser::Error->new('Missing section'))
            if (scalar @_ < 2);

        $section = lc ($section) if ($$self{ci_sections});
        throw(Ini::Parser::Error->new(qq/Unknown section "$section"/))
            if (!exists($$self{parsed}{$section}));

        $$self{parsed}{$section} = Ini::Parser::Section->new($section, $$self{parsed}{$section}, { property_access => $$self{property_access} })
            if (ref($$self{parsed}{$section}) eq 'HASH');

        return $$self{parsed}{$section};
    }

    sub sections {
        my($self) = @_;

        $self->is_parsed();

        my @sections = sort keys (%{$$self{parsed}});

        return @sections;
    }

    sub is_parsed {
        my($self) = @_;

        throw(Ini::Parser::Error->new('Data not parsed'))
            if (!defined($$self{parsed}));

        return 1;
    }

    sub to_hash {
        my($self) = @_;

        my($data, %ret, $section, @sections);
        @sections = $self->sections();
        foreach $section (@sections) {
            $data = $self->section($section);
            $ret{$section} = { $data->to_hash() };
        }

        return %ret;
    }

}

package Ini::Parser::Section;
{
    use 5.006;
    use strict;
    use warnings;

    use Storable qw/dclone/;

    use Try::Tiny::SmartCatch 0.5 qw/:all/;

    my %property_access_disallow = map { $_ => 1 } keys(%{__PACKAGE__::});
    my $rxp_property_access_allowed = qr/^ [a-zA-Z_] [a-zA-Z0-9_]* $/x;

    sub new {
        my($class, $section, $data, $cfg) = @_;

        my $self = {
            section => $section,
            data => dclone($data),
            ci_keys => $$cfg{ci_keys},
        };

        $self = bless($self, $class);

        if ($$cfg{property_access}) {
            foreach my $__key ($self->keys()) {
                next if ($property_access_disallow{$__key});
                next if ($__key !~ /$rxp_property_access_allowed/);

                my ($__sub, $__name);
                $__name = ref($self) . '::' . $__key;
                $__sub = sub {
                    my($self) = @_;
                    return $self->get($__key);
                };

                no strict 'refs';
                *{$__name} = $__sub;
            }
        }

        return $self;
    }

    sub get {
        my($self, $key, ) = @_;

        $key = lc ($key) if ($$self{ci_keys});
        if (exists($$self{data}{$key})) {
            return $$self{data}{$key};
        }
        elsif (scalar @_ > 2) {
            return $_[2];
        }
        else {
            throw(Ini::Parser::Error->new("Unknown key \"$key\" in section \"$$self{section}\""));
        }
    }

    sub keys {
        my($self) = @_;

        my @keys = sort keys(%{$$self{data}});

        return @keys;
    }

    sub values {
        my($self) = @_;

        my @values = @{$$self{data}}{$self->keys()};

        return @values;
    }

    sub to_hash {
        my($self) = @_;

        my $ret = dclone($$self{data});
        return %$ret;
    }

}

package Ini::Parser::Error;
{
    use 5.006;
    use strict;
    use warnings;

    use overload '""' => 'to_string';

    sub new {
        my($class, $msg, $code) = @_;
        return bless({ msg => $msg, code => $code }, $class);
    }

    sub message {
        my($self) = @_;
        return $$self{msg};
    }
    *msg = \&message;

    sub code {
        my($self) = @_;
        return $$self{code};
    }

    sub to_string {
        my($self) = @_;

        my $code = $self->code();
        $code = '0' if (!defined($code));
        return '[' . $code . '] ' . $self->msg();
    }

}


1;

__END__

=head1 NAME

Ini::Parser - simple INI files parser/reader with imports feature!

=head1 VERSION

Version 0.1

=head1 SYNOPSIS

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

=head1 DESCRIPTION

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

=head2 SECTION

Section name can contain characters: a-z, A-Z, 0-9, ':', ' ', '!', '_', '-'
and must have at least one characters length.

If C<ci_sections> argument is provided to constructor, sections are always lowercased.

=head2 KEY

Key can have two different syntaxes:
1. Without quotes. Must begin with one of: a-z, A-Z, 0-9, ':', '_', '-',
and further can contain characters: a-z, A-Z, 0-9, ':', '!', '_', '-'
and must have at least one characters length.

2. With quotes. Must begin and end with double quotes char, and contain
characters: a-z, A-Z, 0-9, ':', '!', ' ', '=', '_', '-'

If C<ci_keys> argument is provided to constructor, keys are always lowercased.

=head2 VALUE

Value can contain almost any character. Also have two forms:

1. Without quotes. There can be any character but without new line character.

2. With quotes. There can be any character without double quote character
(new line character is allowed).

=head2 DIRECTIVES

=head3 IMPORT

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
The same concerns C<import> directive. In previous example, parser find I<section1>,
locate keys I<key1> and I<key2>, next find C<import> directive. Parser
now parses imported file (here: I<guest.ini>). Merge currently parsed content with
imported file, and returns to parsing next data from I<host.ini>.

=head1 EXPORT

There is no items exported. Module just provide class Ini::Parser.

=head1 SUBROUTINES

=head2 Class Ini::Parser

=head3 Ini::Parser::new

Create new instance.

=head4 Arguments

=over

=item C<cfg> (ref. HASH) [opt]

=over 2

=item C<src> - (STRING|OBJECT|GLOB) [opt]

see: L</Ini::Parser::feed>

=item C<src_type> - (STRING) [opt]

see: L</Ini::Parser::feed>

=item C<interpolate> - (BOOL) [opt]

Enable or disable variables interpolation. Defaults to true.

=item C<property_access> - (BOOL) [opt]

Enable or disable property access to data. Defaults to false.

If true, there will be enabled second way to access for data. Recommended is the one with implicit getters:

=item C<ci_sections> - (BOOL) [opt]

If false, sections are always lowercased, and case insensitive when search for it. Defaults to true.

=item C<ci_keys> - (BOOL) [opt]

If false, keys are always lowercased, and case insensitive when search for it. Defaults to true.

=over 3

=item L</Ini::Parser::section>

=item L</Ini::Parser::Section::key>

=back

But sometimes it's convenient to use properties:

    my $value = $ini->section_name->key_name;

It's works only for sections and keys which name doesn't conflict with builtin methods name, and matching
pattern:
    [a-zA-Z_][a-zA-Z0-9_]*

For any other identifier there is only getter access.

=back

=back

=head4 Returns

=over

=item L<Ini::Parser|/Class Ini::Parser> instance.

=back

=head3 Ini::Parser::feed

Feed L<Ini::Parser|/Class Ini::Parser> with data to parse.

=head4 Arguments

=over

=item C<src> - (STRING|OBJECT|GLOB) [opt]

data to feed

=item C<cfg> - (ref. HASH) [opt]

additional config

=over 2

=item C<src_type> - (STRING) [opt]

If not given, will try to guest what to do with C<src>. One of:

=over 3

=item C<string> - C<src> is just string to parse

=item C<object> - C<src> is object with method C<read>

=item C<filename> - C<src> is path to file where data is stored

=item C<filehandler> - C<src> is opened file handler

=back

=back

=back

=head4 Returns

=over

=item C<self> instance.

=back

=head3 Ini::Parser::parse

Parse all feeded sources.

=head4 Arguments

=over

=item B<NONE>

=back

=head4 Returns

=over

=item C<self> instance.

=back

=head3 Ini::Parser::merge

Merge given data with current one.

=head4 Arguments

=over

=item C<src> - (ref. HASH|Ini::Parser)

New data to merge into current instance. If Ini::Parser instance is given,
we call L</Ini::Parser::to_hash> first.

=item C<dst> - (STRING) [opt]

import C<src> into section C<dst>. If given, assume that C<src> is C<dst>
section content. If missing, assume that C<src> is set of sections and
their content.

=back

=head4 Returns

=over

=item C<self> instance.

=back

=head3 Ini::Parser::section

Return whole section data.

=head4 Arguments

=over

=item C<section> - (STRING)

Name of section from file.

=back

=head4 Returns

=over

=item L<Ini::Parser::Section|/Class Ini::Parser::Section> instance. See below.

=back

=head3 Ini::Parser::sections

Returns list of sections names.

=head4 Arguments

=over

=item B<NONE>

=back

=head4 Returns

=over

=item (ARRAY of STRING)

Array of section names from parsed sources.

=back

=head3 Ini::Parser::is_parsed

Check for existent of parsed data.

Raise exception L<Ini::Parser::Error|/Class Ini::Parser::Error> if source is not parsed yet.

=head4 Arguments

=over

=item B<NONE>

=back

=head4 Returns

=over

=item (BOOL)

Always true.

=back

=head3 Ini::Parser::to_hash

Return all parsed structure as HASH.

=head4 Arguments

=over

=item B<NONE>

=back

=head4 Returns

=over

=item (HASH)

Parsed data.

=back

=head3 Ini::Parser::process_instruction

For internal use.

Dispatch found directives to specific callbacks.

When call, try to find method C<Ini::Parser::__process_instruction__ . INSTRUCTION_NAME>, and call it.
In other case, raise L<Ini::Parser::Error|/Class Ini::Parser::Error> exception.

=head4 Arguments

=over

=item instruction - (STRING)

Instruction name.

=item value - (STRING)

Value of directive from .ini file. For example if in .ini file is directive:

    !import = guest.ini

'guest.ini' is value for directive C<import>.

=back

=head4 Returns

=over

=item C<self> instance.

=back

=head3 Ini::Parser::MAX_FEED_FILENAME_LENGTH

For internal use.

Constant that helps for guessing when given for L</Ini::Parser::feed> string is file name or data to parse.

=head2 Class Ini::Parser::Section

=head3 Ini::Parser::Section::new

Create instance of class.

=head4 Arguments

=over

=item section - (STRING)

Section name.

=item data - (ref. HASH)

Section data.

=back

=head4 Returns

=over

=item L<Ini::Parser::Section|/Class Ini::Parser::Section> instance

=back

=head3 Ini::Parser::Section::get

Return single key from section data.

Raise L<Ini::Parser::Error|/Class Ini::Parser::Error> exception if key is not found, unless C<default>
argument is given.

=head4 Arguments

=over

=item key - (STRING)

Key name.

=item default - (MISC) [opt]

Default value to return if C<key> is not found.

=back

=head4 Returns

=over

=item (STRING)

Value

=back

=head3 Ini::Parser::Section::keys

Returns list of all keys from this section.

Keys are always sorted.

=head4 Arguments

=over

=item B<NONE>

=back

=head4 Returns

=over

=item (ARRAY of STRING)

List of keys from this section.

=back

=head3 Ini::Parser::Section::values

Returns list of all values from this section.

Order of values is always matching to order of keys read via L</Ini::Parser::Section::keys>.

=head4 Arguments

=over

=item B<NONE>

=back

=head4 Returns

=over

=item (ARRAY of STRING)

List of values from this section.

=back

=head3 Ini::Parser::Section::to_hash

Return all section data as HASH.

=head4 Arguments

=over

=item B<NONE>

=back

=head4 Returns

=over

=item (HASH)

Section data.

=back

=head2 Class Ini::Parser::Error

=head3 Ini::Parser::Error::new

Create new instance.

=head4 Arguments

=over

=item msg - (STRING)

Error message.

=item code - (INT)

Error code.

=back

=head4 Returns

=over

=item L<Ini::Parser::Error|/Class Ini::Parser::Error> instance.

=back

=head3 Ini::Parser::Error::message

Returns error message.

=head4 Arguments

=over

=item B<NONE>

=back

=head4 Returns

=over

=item (STRING)

Error message.

=back

=head3 Ini::Parser::Error::msg

Alias to L</Ini::Parser::Error::message>.

=head3 Ini::Parser::Error::code

Returns error code.

=head4 Arguments

=over

=item B<NONE>

=back

=head4 Returns

=over

=item (STRING)

Error code.

=back

=head3 Ini::Parser::Error::to_string

Returns string representation of exception.

=head4 Arguments

=over

=item B<NONE>

=back

=head4 Returns

=over

=item (STRING)

String representation of exception.

=back

=head1 SEE ALSO

=over

=item Other .ini or config parsers

L<Config::Tiny>, L<Config::Simple>, L<Config::General>

=item L<Try::Tiny::SmartCatch>

=back

=head1 AUTHOR

Marcin Sztolcman, C<< <marcin at urzenia.net> >>

=head1 BUGS

Please report any bugs or feature requests through the web interface at
L<http://github.com/mysz/ini-parser/issues>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Ini::Parser

You can also look for information at:

=over 4

=item * Ini::Parser home & source code

L<http://github.com/mysz/ini-parser>

=item * Issue tracker (report bugs here)

L<http://github.com/mysz/ini-parser/issues>

=item * Search CPAN

L<http://search.cpan.org/dist/ini-parser/>

=back

=head1 LICENSE AND COPYRIGHT

    Copyright (c) 2013 Marcin Sztolcman. All rights reserved.

    This program is free software; you can redistribute
    it and/or modify it under the terms of the MIT license.

=cut

