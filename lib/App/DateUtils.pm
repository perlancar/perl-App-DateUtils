package App::DateUtils;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

our %SPEC;

$SPEC{parse_date} = {
    v => 1.1,
    summary => 'Parse date string(s) using one of several modules',
    args => {
        module => {
            schema  => ['str*', in=>[
                'DateTime::Format::Alami::EN',
                'DateTime::Format::Alami::ID',
                'DateTime::Format::Natural',
            ]],
            default => 'DateTime::Format::Natural',
            cmdline_aliases => {m=>{}},
        },
        time_zone => {
            schema => 'str*',
            cmdline_aliases => {timezone=>{}},
        },
        dates => {
            schema => ['array*', of=>'str*', min_len=>1],
            'x.name.is_plural' => 1,
            req => 1,
            pos => 0,
            greedy => 1,
        },
    },
};
sub parse_date {
    my %args = @_;

    my $mod = $args{module};

    my $parser;
    if ($mod eq 'DateTime::Format::Alami::EN') {
        require DateTime::Format::Alami::EN;
        $parser = DateTime::Format::Alami::EN->new(
            ( time_zone => $args{time_zone} ) x !!(defined($args{time_zone})),
        );
    } elsif ($mod eq 'DateTime::Format::Alami::ID') {
        require DateTime::Format::Alami::ID;
        $parser = DateTime::Format::Alami::ID->new(
            ( time_zone => $args{time_zone} ) x !!(defined($args{time_zone})),
        );
    } elsif ($mod eq 'DateTime::Format::Natural') {
        require DateTime::Format::Natural;
        $parser = DateTime::Format::Natural->new(
            ( time_zone => $args{time_zone} ) x !!(defined($args{time_zone})),
        );
    }

    my @res;
    for my $date (@{ $args{dates} }) {
        my $rec = { original => $date };
        if ($mod =~ /^DateTime::Format::(Alami|Natural)/) {
            my $dt = $parser->parse_datetime($date);
            my $success = $mod =~ /Alami/ ? $dt : $parser->success;

            if ($success) {
                $rec->{is_parseable} = 1;
                $rec->{as_epoch} = $dt->epoch;
                $rec->{as_datetime_obj} = "$dt";
            } else {
                $rec->{is_parseable} = 0;
            }
        }
        push @res, $rec;
    }
    [200, "OK", \@res];
}

$SPEC{parse_duration} = {
    v => 1.1,
    summary => 'Parse duration string(s) using one of several modules',
    args => {
        module => {
            schema  => ['str*', in=>[
                'DateTime::Format::Duration',
                'Time::Duration::Parse',
            ]],
            default => 'Time::Duration::Parse',
            cmdline_aliases => {m=>{}},
        },
        durations => {
            schema => ['array*', of=>'str*', min_len=>1],
            'x.name.is_plural' => 1,
            req => 1,
            pos => 0,
            greedy => 1,
        },
    },
};
sub parse_duration {
    my %args = @_;

    my $mod = $args{module};

    my $parser;
    if ($mod eq 'DateTime::Format::Duration') {
        require DateTime::Format::Duration;
        $parser = DateTime::Format::Duration->new(
        );
    } elsif ($mod eq 'Time::Duration::Parse') {
        require Time::Duration::Parse;
    }

    my @res;
    for my $dur (@{ $args{durations} }) {
        my $rec = { original => $dur };
        if ($mod eq 'DateTime::Format::Duration') {
            my $dtdur = $parser->parse_duration($dur);
            if ($dtdur) {
                $rec->{is_parseable} = 1;
                $rec->{as_dtdur_obj} = "$dtdur";
                $rec->{as_secs} = $dtdur->in_units('seconds');
            } else {
                $rec->{is_parseable} = 0;
            }
        } elsif ($mod eq 'Time::Duration::Parse') {
            my $secs;
            eval { $secs = Time::Duration::Parse::parse_duration($dur) };
            if ($@) {
                $rec->{is_parseable} = 0;
                $rec->{error_msg} = $@;
                $rec->{error_msg} =~ s/\n+/ /g;
            } else {
                $rec->{is_parseable} = 1;
                $rec->{as_secs} = $secs;
            }
        }
        push @res, $rec;
    }
    [200, "OK", \@res];
}

1;
# ABSTRACT: An assortment of date-/time-related CLI utilities

=head1 SYNOPSIS

This distribution provides the following command-line utilities related to
date/time:

#INSERT_EXECS_LIST


=head1 SEE ALSO

L<App::datecalc>

=cut
