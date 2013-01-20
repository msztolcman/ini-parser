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
            ([a-zA-Z0-9:-]+)
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
                    "([a-zA-Z0-9:!-]+)" # quoted key name
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
        if (!sysread($fh, $data, -s $fh, 0)) {
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
                if (length($src) < MAX_FEED_FILENAME_LENGTH && index($src, "\n") < 0) {
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

        my @sections = keys (%{$$self{parsed}});

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

        my @keys = keys(%{$$self{data}});

        return @keys;
    }

    sub values {
        my($self) = @_;

        my @values = values(%{$$self{data}});

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
