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

    my $rxp_section = qr/
        (?:^|\r?\n)+
        [ \t]*
        \[
            ([a-zA-Z0-9: !-]+)
        \]
        [ \t]*
        (?=\r?\n|$)
    /x;

    my $rxp_data = qr/
        (?:
            (?:
                [ \t]*
                (?:
                    ([a-zA-Z0-9:-][a-zA-Z0-9:!-]*)   # normal key name
                    |
                    "([a-zA-Z0-9:! =-]+)" # quoted key name
                    |
                    (![a-zA-Z0-9:!-]+)  # instruction
                )
                [ \t]*
                =
                [ \t]*
                (?:
                    "([^"]*)"
                    |
                    (.*)
                )?
                [ \t]*
                (?:\r?\n|$)+
            )
            |
            (?:\r?\n|$)+
        )
    /x;


    sub __trim {
        my ($s) = @_;

        $s =~ s/^\s+//;
        $s =~ s/\s+$//;

        return $s;
    }

    sub new {
        my($class, $cfg) = @_;

        my($self);

        $self = {
            source => [],
            parsed => undef,
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

    sub parse {
        my($self) = @_;

        my ($data, $i, $i_max, $key, @parts, $section, $src, $value);

        $$self{parsed} = {}
            if (!defined($$self{parsed}));

        foreach $src (@{$$self{source}}) {
            @parts = split(/$rxp_section/, __trim($src));
            $i_max = @parts;

            for ($i = 1; $i < $i_max; $i += 2) {
                ($section, $data) = map {
                    defined($_) ? __trim($_) : ''
                } @parts[$i, $i+1];

                $$self{parsed}{$section} = {}
                    if (!defined($$self{parsed}{$section}));

                while ($data =~ /$rxp_data/g) {
                    $value = (defined($4) ? $4 : $5);

                    if (defined($3)) {
                        $self->process_instruction($3, $value);
                    }
                    else {
                        $key = (defined($1) ? $1 : $2);
                        next if (!defined($key));

                        $$self{parsed}{$section}{$key} = $value;
                    }
                }
            }
        }

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
        my ($self, $section) = @_;

        $self->is_parsed();

        throw(Ini::Parser::Error->new('Missing section'))
            if (scalar @_ < 2);

        throw(Ini::Parser::Error->new(qq/Unknown section "$section"/))
            if (!exists($$self{parsed}{$section}));

        $$self{parsed}{$section} = Ini::Parser::Section->new($section, $$self{parsed}{$section})
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

        my ($data, %ret, $section, @sections);
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

    sub new {
        my($class, $section, $data) = @_;

        my $self = {
            section => $section,
            data => dclone($data),
        };
        return bless($self, $class);
    }

    sub get {
        my($self, $key, ) = @_;

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

        my @values = sort values(%{$$self{data}});

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

Ini::Parser - simple INI files parser with imports feature!

=head1 VERSION

Version 0.1

=head1 SYNOPSIS

    use Ini::Parser;

    # create object and feed with some data (optional)
    my $ini = Ini::Parser->new({ src => 'filename.ini', src_type => 'filename' });
    my $Ini = Ini::Parser->new({ src => $filehandler, src_type => 'filehandler' });
    my $Ini = Ini::Parser->new({ src => $obj_with_read_method, src_type => 'filenamobject' });
    my $Ini = Ini::Parser->new({ src => $ini_in_string, src_type => 'string' });

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

=head2 SECTION

Section name can contain characters: a-z, A-Z, 0-9, ':', ' ', '!', '-'
and must have at least one characters length.

=head2 KEY

Key can have two different syntaxes:
1. Without quotes. Must begin with one of: a-z, A-Z, 0-9, ':', '-',
and further can contain characters: a-z, A-Z, 0-9, ':', '!', '-'
and must have at least one characters length.

2. With quotes. Must begin and end with double quotes char, and contain
characters: a-z, A-Z, 0-9, ':', '!', ' ', '=', '-'

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

=head1 SUBROUTINES/METHODS

=head2 Ini::Parser::new

Create new instance.

=head3 Arguments

=over

=item C<cfg> (ref. HASH) [opt]

=over 2

=item C<src> - (STRING|OBJECT|GLOB) [opt]

see: Ini::Parser::feed

=item C<src_type> - (STRING) [opt]

see: Ini::Parser::feed

=back

=back

=head3 Returns

=over

=item C<Ini::Parser> instance.

=back

=head2 Ini::Parser::feed

Feed C<Ini::Parser> with data to parse.

=head3 Arguments

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

=head3 Returns

=over

=item C<self> instance.

=back

=head2 Ini::Parser::parse

Parse all feeded sources.

=head3 Arguments

=over

=item B<NONE>

=back

=head3 Returns

=over

=item C<self> instance.

=back

=head2 Ini::Parser::merge

Merge given data with current one.

=head3 Arguments

=over

=item C<src> - (ref. HASH|Ini::Parser)

New data to merge into current instance. If Ini::Parser instance is given,
we call L<Ini::Parser::to_hash> first.

=item C<dst> - (STRING) [opt]

import C<src> into section C<dst>. If given, assume that C<src> is C<dst>
section content. If missing, assume that C<src> is set of sections and
their content.

=back

=head3 Returns

=over

=item C<self> instance.

=back

=head2 Ini::Parser::section

Return whole section data.

=head3 Arguments

=over

=item C<section> - (STRING)

Name of section from file.

=back

=head3 Returns

=over

=item C<Ini::Parser::Section> instance. See below.

=back

=head2 Ini::Parser::sections

Returns list of sections names.

=head3 Arguments

=over

=item B<NONE>

=back

=head3 Returns

=over

=item sections - (ARRAY of STRING)

Array of section names from parsed sources.

=back

=head2 Ini::Parser::is_parsed

Description

=head3 Arguments

=over

=item

=back

=head3 Returns

=over

=item

=back

=head2 Ini::Parser::to_hash

Description

=head3 Arguments

=over

=item

=back

=head3 Returns

=over

=item

=back

=head2 Ini::Parser::process_instruction

Description

=head3 Arguments

=over

=item

=back

=head3 Returns

=over

=item

=back

=head2 Ini::Parser::MAX_FEED_FILENAME_LENGTH

Description

=head3 Arguments

=over

=item

=back

=head3 Returns

=over

=item

=back

=head2 Ini::Parser::Section::new

Description

=head3 Arguments

=over

=item

=back

=head3 Returns

=over

=item

=back

=head2 Ini::Parser::Section::get

Description

=head3 Arguments

=over

=item

=back

=head3 Returns

=over

=item

=back

=head2 Ini::Parser::Section::keys

Description

=head3 Arguments

=over

=item

=back

=head3 Returns

=over

=item

=back

=head2 Ini::Parser::Section::values

Description

=head3 Arguments

=over

=item

=back

=head3 Returns

=over

=item

=back

=head2 Ini::Parser::Section::to_hash

Description

=head3 Arguments

=over

=item

=back

=head3 Returns

=over

=item

=back

=head1 SEE ALSO

=over 4

=item L<https://github.com/mysz/try-tiny-smartcatch>

Try::Tiny::SmartCatch home.

=item L<Try::Tiny>

Minimal try/catch with proper localization of $@, base of L<Try::Tiny::SmartCatch>

=item L<TryCatch>

First class try catch semantics for Perl, without source filters.

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
