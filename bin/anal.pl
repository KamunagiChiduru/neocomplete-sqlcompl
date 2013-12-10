#!env perl

use 5.010;
use utf8;
use strict;
use warnings;
use Carp qw/croak cluck/;
use AnyEvent::JSONRPC::TCP::Server;
use DBI;
use DBIx::Inspector;
use Regexp::Assemble;

sub something_wrong($)
{
    warn $_[0];
    {
        code => -32000,
        message => 'something wrong',
        data => $_[0],
    }
}

sub datasource
{
    my ($args)= @_;

    my %dbd= (
        pg => 'Pg',
    );

    return sprintf 'dbi:%s:dbname=%s;port=%s',
        $dbd{$args->{dbtype}},
        $args->{dbname},
        $args->{port} || 5432,
    ;
}

my $server= AnyEvent::JSONRPC::TCP::Server->new(
    address => '127.0.0.1',
    port => 12345,
);

$server->reg_cb(
    databases => sub{
        my ($res_cv, $args)= @_;

        my @keys= qw/name owner encoding collate ctype access_privileges/;
        my @databases;

        my $trimer= Regexp::Assemble->new(qr/^\s+/, qr/\s+$/);

        chomp(my @lines= `psql --username=$args->{username} --tuples-only --list`);

        for my $line (@lines)
        {
            $line=~ s/$trimer->re//g;

            my %fields;
            @fields{@keys}= split /\s*\|\s*/, $line;

            push @databases, \%fields;
        }

        $res_cv->result(\@databases);
    },
    catalogs => sub{
        my ($res_cv, $args)= @_;

        my $dbh;
        eval
        {
            $dbh= DBI->connect(datasource($args), $args->{username}, $args->{password}, {RaiseError => 1});

            my @result;
            my $sth= $dbh->table_info('%', '', '');
            while(my $row= $sth->fetchrow_hashref)
            {
                push @result, {
                    name => $row->{TABLE_CAT},
                    type => 'catalog',
                    remarks => $row->{REMARKS},
                };
            }

            $res_cv->result(\@result);
        };
        if($@)
        {
            $res_cv->error(something_wrong $@);
        }

        $dbh->disconnect if $dbh;
    },
    schemas => sub{
        my ($res_cv, $args)= @_;

        my $dbh;
        eval
        {
            $dbh= DBI->connect(datasource($args), $args->{username}, $args->{password}, {RaiseError => 1});

            my @result;
            my $sth= $dbh->table_info('', '%', '');
            while(my $row= $sth->fetchrow_hashref)
            {
                push @result, {
                    name => $row->{TABLE_SCHEM},
                    type => 'schema',
                    remarks => $row->{REMARKS},
                };
            }

            $res_cv->result(\@result);
        };
        if($@)
        {
            $res_cv->error(something_wrong $@);
        }

        $dbh->disconnect if $dbh;
    },
    tables => sub{
        my ($res_cv, $args)= @_;

        my $dbh;
        eval
        {
            $dbh= DBI->connect(datasource($args), $args->{username}, $args->{password}, {RaiseError => 1});
            my $inspector= DBIx::Inspector->new(dbh => $dbh);

            my @result;

            for my $table ($inspector->tables)
            {
                next if $table->schema ne $args->{schema};

                push @result, {
                    schema => $table->schema,
                    name => $table->name,
                    comment => '',
                    type => lc $table->type,
                };
            }

            $res_cv->result(\@result);
        };
        if($@)
        {
            $res_cv->error(something_wrong $@);
        }

        $dbh->disconnect if $dbh;
    },
    columns => sub{
        my ($res_cv, $args)= @_;

        my $dbh;
        eval
        {
            $dbh= DBI->connect(datasource($args), $args->{username}, $args->{password}, {RaiseError => 1});
            my $inspector= DBIx::Inspector->new(dbh => $dbh);

            my $table= $inspector->table($args->{table});
            my @result;

            for my $column ($table->columns)
            {
                push @result, {
                    schema => $table->schema,
                    table => $table->name,
                    name => $column->name,
                    comment => $column->remarks,
                    type => $column->type_name,
                    column_size => $column->column_size,
                    nullable => $column->nullable,
                };
            }

            $res_cv->result(\@result);
        };
        if($@)
        {
            $res_cv->error(something_wrong $@);
        }

        $dbh->disconnect if $dbh;
    },
);

AnyEvent->condvar->recv;

1;

