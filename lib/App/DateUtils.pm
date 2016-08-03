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

my %all_modules_arg = (
    all_modules => {
        summary => 'Parse using all installed modules and '.
            'return all the result at once',
        schema => ['bool*', is=>1],
        cmdline_aliases => {a=>{}},
    },
);

my @parse_date_modules = (
    'DateTime::Format::Alami::EN',
    'DateTime::Format::Alami::ID',
    'DateTime::Format::Flexible',
    'DateTime::Format::Flexible(de)',
    'DateTime::Format::Flexible(es)',
    'DateTime::Format::Natural',
);

my @parse_duration_modules = (
    'DateTime::Format::Alami::EN',
    'DateTime::Format::Alami::ID',
    'DateTime::Format::Natural',
    'Time::Duration::Parse',
);

$SPEC{parse_date} = {
    v => 1.1,
    summary => 'Parse date string(s) using one of several modules',
    args => {
        module => {
            schema  => ['str*', in=>\@parse_date_modules],
            default => 'DateTime::Format::Flexible',
            cmdline_aliases => {m=>{}},
        },
        %all_modules_arg,
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

    my %mods; # val = 1 if installed
    if ($args{all_modules}) {
        require Module::Installed::Tiny;
        for my $mod0 (@parse_date_modules) {
            (my $mod = $mod0) =~ s/\(.+//;
            $mods{$mod0} = Module::Installed::Tiny::module_installed($mod) ?
                1:0;
        }
    } else {
        %mods = ($args{module} => 1);
    }

    my @res;
    for my $mod (sort keys %mods) {
        my $mod_is_installed = $mods{$mod};

        my $parser;
        if ($mod_is_installed) {
            if ($mod eq 'DateTime::Format::Alami::EN') {
                require DateTime::Format::Alami::EN;
                $parser = DateTime::Format::Alami::EN->new(
                    ( time_zone => $args{time_zone} ) x
                        !!(defined($args{time_zone})),
                );
            } elsif ($mod eq 'DateTime::Format::Alami::ID') {
                require DateTime::Format::Alami::ID;
                $parser = DateTime::Format::Alami::ID->new(
                    ( time_zone => $args{time_zone} ) x
                        !!(defined($args{time_zone})),
                );
            } elsif ($mod =~ /^DateTime::Format::Flexible/) {
                require DateTime::Format::Flexible;
                $parser = DateTime::Format::Flexible->new(
                );
            } elsif ($mod eq 'DateTime::Format::Natural') {
                require DateTime::Format::Natural;
                $parser = DateTime::Format::Natural->new(
                    ( time_zone => $args{time_zone} ) x
                        !!(defined($args{time_zone})),
                );
            } else {
                return [400, "Unknown module '$mod'"];
            }
        }

      DATE:
        for my $date (@{ $args{dates} }) {
            my $rec = { original => $date, module => $mod };
            unless ($mod_is_installed) {
                $rec->{error_msg} = "module not installed";
                goto PUSH_RESULT;
            }
            if ($mod =~ /^DateTime::Format::Alami/) {
                my $res;
                eval { $parser->parse_datetime($date, {format=>'combined'}) };
                if ($@) {
                    $rec->{is_parseable} = 0;
                } else {
                    $rec->{is_parseable} = 1;
                    $rec->{as_epoch} = $res->{epoch};
                    $rec->{as_datetime_obj} = "$res->{DateTime}";
                    $rec->{pattern} = $res->{pattern};
                }
            } elsif ($mod =~ /^DateTime::Format::Flexible/) {
                my $dt;
                my %opts;
                $opts{lang} = [$1] if $mod =~ /\((\w+)\)$/;
                eval { $dt = $parser->parse_datetime(
                    $date,
                    %opts,
                ) };
                my $err = $@;
                if (!$err) {
                    $rec->{is_parseable} = 1;
                    $rec->{as_epoch} = $dt->epoch;
                    $rec->{as_datetime_obj} = "$dt";
                } else {
                    $err =~ s/\n/ /g;
                    $rec->{is_parseable} = 0;
                    $rec->{error_msg} = $err;
                }
            } elsif ($mod =~ /^DateTime::Format::Natural/) {
                my $dt = $parser->parse_datetime($date);
                if ($parser->success) {
                    $rec->{is_parseable} = 1;
                    $rec->{as_epoch} = $dt->epoch;
                    $rec->{as_datetime_obj} = "$dt";
                } else {
                    $rec->{is_parseable} = 0;
                    $rec->{error_msg} = $parser->error;
                }
            }
          PUSH_RESULT:
            push @res, $rec;
        } # for dates
    } # for mods

    [200, "OK", \@res, {'table.fields'=>[qw/module original is_parseable as_epoch as_datetime_obj error_msg/]}];
}

$SPEC{parse_date_using_df_flexible} = {
    v => 1.1,
    summary => 'Parse date string(s) using DateTime::Format::Flexible',
    args => {
        %time_zone_arg,
        %dates_arg,
        lang => {
            schema => ['str*', in=>[qw/de en es/]],
            default => 'en',
        },
    },
    examples => [
        {args => {dates => ['23rd Jun']}},
        {args => {dates => ['23 Dez'], lang=>'de'}},
        {args => {dates => ['foo']}},
    ],
};
sub parse_date_using_df_flexible {
    my %args = @_;
    my $lang = $args{lang};
    my $module = 'DateTime::Format::Flexible';
    $module .= "(de)" if $lang eq 'de';
    $module .= "(es)" if $lang eq 'es';
    parse_date(module=>$module, %args);
}

$SPEC{parse_date_using_df_natural} = {
    v => 1.1,
    summary => 'Parse date string(s) using DateTime::Format::Natural',
    args => {
        %time_zone_arg,
        %dates_arg,
    },
    examples => [
        {args => {dates => ['23rd Jun']}},
        {args => {dates => ['foo']}},
    ],
    links => [
        {summary => 'The official CLI for DateTime::Format::Natural', url=>'dateparse'},
    ],
};
sub parse_date_using_df_natural {
    my %args = @_;
    parse_date(module=>'DateTime::Format::Natural', %args);
}

$SPEC{parse_date_using_df_alami_en} = {
    v => 1.1,
    summary => 'Parse date string(s) using DateTime::Format::Alami::EN',
    args => {
        %time_zone_arg,
        %dates_arg,
    },
    examples => [
        {args => {dates => ['23 May']}},
        {args => {dates => ['foo']}},
    ],
};
sub parse_date_using_df_alami_en {
    my %args = @_;
    parse_date(module=>'DateTime::Format::Alami::EN', %args);
}

$SPEC{parse_date_using_df_alami_id} = {
    v => 1.1,
    summary => 'Parse date string(s) using DateTime::Format::Alami::ID',
    args => {
        %time_zone_arg,
        %dates_arg,
    },
    examples => [
        {args => {dates => ['23 Mei']}},
        {args => {dates => ['foo']}},
    ],
};
sub parse_date_using_df_alami_id {
    my %args = @_;
    parse_date(module=>'DateTime::Format::Alami::ID', %args);
}

$SPEC{parse_duration} = {
    v => 1.1,
    summary => 'Parse duration string(s) using one of several modules',
    args => {
        module => {
            schema  => ['str*', in=>\@parse_duration_modules],
            default => 'Time::Duration::Parse',
            cmdline_aliases => {m=>{}},
        },
        %durations_arg,
        %all_modules_arg,
    },
};
sub parse_duration {
    my %args = @_;

    my %mods; # val = 1 if installed
    if ($args{all_modules}) {
        require Module::Installed::Tiny;
        for my $mod0 (@parse_duration_modules) {
            (my $mod = $mod0) =~ s/\(.+//;
            $mods{$mod0} = Module::Installed::Tiny::module_installed($mod) ?
                1:0;
        }
    } else {
        %mods = ($args{module} => 1);
    }

    my @res;
    for my $mod (sort keys %mods) {
        my $mod_is_installed = $mods{$mod};

        my $parser;
        if ($mod_is_installed) {
            if ($mod eq 'DateTime::Format::Alami::EN') {
                require DateTime::Format::Alami::EN;
                $parser = DateTime::Format::Alami::EN->new();
            } elsif ($mod eq 'DateTime::Format::Alami::ID') {
                require DateTime::Format::Alami::ID;
                $parser = DateTime::Format::Alami::ID->new();
            } elsif ($mod eq 'DateTime::Format::Natural') {
                require DateTime::Format::Natural;
                $parser = DateTime::Format::Natural->new();
            } elsif ($mod eq 'Time::Duration::Parse') {
                require Time::Duration::Parse;
            }
        }

      DURATION:
        for my $dur (@{ $args{durations} }) {
            my $rec = { original => $dur, module => $mod };
            unless ($mod_is_installed) {
                $rec->{error_msg} = "module not installed";
                goto PUSH_RESULT;
            }
            if ($mod =~ /^DateTime::Format::Alami/) {
                my $res;
                eval { $res = $parser->parse_datetime_duration($dur, {format=>'combined'}) };
                if ($@) {
                    $rec->{is_parseable} = 0;
                } else {
                    require DateTime::Format::Duration::ISO8601;
                    my $dtdurf = DateTime::Format::Duration::ISO8601->new;
                    $rec->{is_parseable} = 1;
                    $rec->{as_dtdur_obj} = $dtdurf->format_duration($res->{Duration});
                    $rec->{as_secs} = $res->{seconds};
                }
            } elsif ($mod =~ /^DateTime::Format::Natural/) {
                my @dt = $parser->parse_datetime_duration($dur);
                if (@dt > 1) {
                    require DateTime::Format::Duration::ISO8601;
                    my $dtdurf = DateTime::Format::Duration::ISO8601->new;
                    my $dtdur = $dt[1]->subtract_datetime($dt[0]);
                    $rec->{is_parseable} = 1;
                    $rec->{date1} = "$dt[0]";
                    $rec->{date2} = "$dt[1]";
                    $rec->{as_dtdur_obj} = $dtdurf->format_duration($dtdur);
                    $rec->{as_secs} =
                        $dtdur->years * 365.25*86400 +
                        $dtdur->months * 30.4375*86400 +
                        $dtdur->weeks * 7*86400 +
                        $dtdur->days * 86400 +
                        $dtdur->hours * 3600 +
                        $dtdur->minutes * 60 +
                        $dtdur->seconds +
                        $dtdur->nanoseconds * 1e-9;
                } else {
                    $rec->{is_parseable} = 0;
                    $rec->{error_msg} = $parser->error;
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
          PUSH_RESULT:
            push @res, $rec;
        } # for durations
    } # for modules

    [200, "OK", \@res, {'table.fields'=>[qw/module original is_parseable as_secs as_dtdur_obj error_msg/]}];
}

$SPEC{parse_duration_using_df_alami_en} = {
    v => 1.1,
    summary => 'Parse duration string(s) using DateTime::Format::Alami::EN',
    args => {
        %durations_arg,
    },
    examples => [
        {args => {durations => ['2h, 3mins']}},
        {args => {durations => ['foo']}},
    ],
};
sub parse_duration_using_df_alami_en {
    my %args = @_;
    parse_duration(module=>'DateTime::Format::Alami::EN', %args);
}

$SPEC{parse_duration_using_df_alami_id} = {
    v => 1.1,
    summary => 'Parse duration string(s) using DateTime::Format::Alami::ID',
    args => {
        %durations_arg,
    },
    examples => [
        {args => {durations => ['2j, 3mnt']}},
        {args => {durations => ['foo']}},
    ],
};
sub parse_duration_using_df_alami_id {
    my %args = @_;
    parse_duration(module=>'DateTime::Format::Alami::ID', %args);
}

$SPEC{parse_duration_using_df_natural} = {
    v => 1.1,
    summary => 'Parse duration string(s) using DateTime::Format::Natural',
    args => {
        %durations_arg,
    },
    examples => [
        {args => {durations => ['for 2 weeks']}},
        {args => {durations => ['from 23 Jun to 29 Jun']}},
        {args => {durations => ['foo']}},
    ],
};
sub parse_duration_using_df_natural {
    my %args = @_;
    parse_duration(module=>'DateTime::Format::Natural', %args);
}

$SPEC{parse_duration_using_td_parse} = {
    v => 1.1,
    summary => 'Parse duration string(s) using Time::Duration::Parse',
    args => {
        %durations_arg,
    },
    examples => [
        {args => {durations => ['2 days 13 hours']}},
        {args => {durations => ['foo']}},
    ],
};
sub parse_duration_using_td_parse {
    my %args = @_;
    parse_duration(module=>'Time::Duration::Parse', %args);
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


=head1 append:SEE ALSO

L<App::datecalc>

=cut
