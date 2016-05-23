package App::DateUtils;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

our %SPEC;

my %time_zone_arg = (
    time_zone => {
        schema => 'str*',
        cmdline_aliases => {timezone=>{}},
    },
);

my %dates_arg = (
    dates => {
        schema => ['array*', of=>'str*', min_len=>1],
        'x.name.is_plural' => 1,
        req => 1,
        pos => 0,
        greedy => 1,
    },
);

my %durations_arg = (
    durations => {
        schema => ['array*', of=>'str*', min_len=>1],
        'x.name.is_plural' => 1,
        req => 1,
        pos => 0,
        greedy => 1,
    },
);

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
        %time_zone_arg,
        %dates_arg,
    },
    examples => [
        {
            argv => ['23 sep 2015','tomorrow','foo'],
        },
    ],
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

$SPEC{parse_date_using_df_natural} = {
    v => 1.1,
    summary => 'Parse date string(s) using DateTime::Format::Natural',
    args => {
        %time_zone_arg,
        %dates_arg,
    },
};
sub parse_date_using_df_natural {
    my %args = @_;
    parse_date(module=>'DateTime::Format::Natural', %args);
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
        %durations_arg,
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

$SPEC{parse_duration_using_df_duration} = {
    v => 1.1,
    summary => 'Parse date string(s) using DateTime::Format::Duration',
    args => {
        %durations_arg,
    },
};
sub parse_duration_using_df_duration {
    my %args = @_;
    parse_duration(module=>'DateTime::Format::Duration', %args);
}

$SPEC{dateconv} = {
    v => 1.1,
    summary => 'Convert date to another format',
    args => {
        date => {
            schema => ['date*', {
                'x.perl.coerce_to' => 'DateTime',
                'x.perl.coerce_rules' => ['str_alami'],
            }],
            req => 1,
            pos => 0,
        },
        to => {
            schema => ['str*', in=>[qw/epoch ymd/]], # XXX: iso8601, ...
            default => 'epoch',
        },
    },
    result_naked => 1,
    examples => [
        {
            summary => 'Convert "today" to epoch',
            args => {date => 'today'},
            test => 0,
        },
        {
            summary => 'Convert epoch to ymd',
            args => {date => '1463702400', to=>'ymd'},
            result => '2016-05-20',
        },
    ],
};
sub dateconv {
    my %args = @_;
    my $date = $args{date};
    my $to   = $args{to};

    if ($to eq 'epoch') {
        return $date->epoch;
    } elsif ($to eq 'ymd') {
        return $date->ymd;
    } else {
        die "Unknown format '$to'";
    }
}

$SPEC{durconv} = {
    v => 1.1,
    summary => 'Convert duration to another format',
    args => {
        duration => {
            schema => ['duration*', {
                'x.perl.coerce_to' => 'DateTime::Duration',
            }],
            req => 1,
            pos => 0,
        },
        to => {
            schema => ['str*', in=>[qw/secs hash/]], # XXX: iso8601, ...
            default => 'secs',
        },
    },
    result_naked => 1,
    examples => [
        {
            summary => 'Convert "3h2m" to number of seconds',
            args => {duration => '3h2m'},
            result => 10920,
        },
    ],
};
sub durconv {
    my %args = @_;
    my $dur = $args{duration};
    my $to  = $args{to};

    if ($to eq 'secs') {
        # approximation
        return (
            $dur->years       * 365*86400 +
            $dur->months      *  30*86400 +
            $dur->weeks       *   7*86400 +
            $dur->days        *     86400 +
            $dur->hours       *      3600 +
            $dur->minutes     *        60 +
            $dur->seconds     *         1 +
            $dur->nanoseconds *      1e-9
        );
    } elsif ($to eq 'hash') {
        my $h = {
            years => $dur->years,
            months => $dur->months,
            weeks => $dur->weeks,
            days => $dur->days,
            hours => $dur->hours,
            minutes => $dur->minutes,
            seconds => $dur->seconds,
            nanoseconds => $dur->nanoseconds,
        };
        for (keys %$h) {
            delete $h->{$_} if $h->{$_} == 0;
        }
        return $h;
    } else {
        die "Unknown format '$to'";
    }
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
