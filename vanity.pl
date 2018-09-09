#!/usr/bin/env perl
####################################################################################################

use 5.010;
use strict;
use warnings;

use JSON;
use Irssi;
use Irssi::Irc;
use File::Slurp;

####################################################################################################

sub sig_event_privmsg($$$$);
sub sig_message_irc_notice($$$$$);
sub set_host($$$);
sub cmd_vanity($$$);
sub show_vanity();
sub load_vanity();
sub save_vanity();
sub is_oper();
sub sigh(@);

my $VANITY_FILE = '/home/robot/vanity/vanity.json';
my $vanity;

####################################################################################################

main:
    {
    unless (is_oper)
        {
        sigh 'we are not an oper.';
        sigh 'oper up and reload this script.';

        return;
        }

    Irssi::signal_add_first({
        'message irc notice' => \&sig_message_irc_notice,
        'event privmsg'      => \&sig_event_privmsg,
        });

    Irssi::command_bind('vanity' => \&cmd_vanity);

    load_vanity();
    show_vanity();
    }

####################################################################################################

sub sig_event_privmsg($$$$)
    {
    my ($SERV, $data, $nick, $address) = @_;
    my ($target, $text) = split(/ :/, $data, 2);

    $nick = lc $nick;

    my $vain_host;

    if ($text =~ /^\.vanity (\S+) (\S+)$/)
        {
        # be a jerk to somebody else

        $nick = lc $1;
        $vain_host = $2;
        }
    elsif ($text =~ /^\.vanity (\S+)$/)
        {
        # set your own host

        $vain_host = $1;
        }

    return unless $vain_host;

    if ($vain_host eq 'delete')
        {
        set_host($SERV, $nick, 'irc.lycaeum.fun');

        delete $vanity->{$nick};
        save_vanity();

        $SERV->command("MSG ${target} bye, $nick");
        }
    elsif ($vain_host =~ /^[a-zA-Z0-9\.\-]{1,50}$/)
        {
        set_host($SERV, $nick, $vain_host);

        $vanity->{$nick} = $vain_host;
        save_vanity();

        $SERV->command("MSG ${target} ok, $nick");
        }
    else
        {
        $SERV->command("MSG ${target} too vain, $nick");
        }
    }

####################################################################################################

sub sig_message_irc_notice($$$$$)
    {
    my ($SERV, $msg, $nick, $addr, $target) = @_;

    if ($msg =~ /^\*\*\* Client connecting: (\S+) \((.+?)\)/)
        {
        my $nick = $1;
        my $host = $2;

        $nick = lc $nick;

        if (my $vain_host = $vanity->{$nick})
            {
            set_host($SERV, $nick, $vain_host);
            }
        }
    }

####################################################################################################

sub set_host($$$)
    {
    my ($SERV, $nick, $vain_host) = @_;

    $SERV->send_raw("CHGHOST $nick :$vain_host");

    sigh "$nick -> $vain_host";
    }

####################################################################################################

sub cmd_vanity($$$)
    {
    my $data = shift;
    my $SERV = shift;
    my $item = shift;

    if ($data eq 'once')
        {
        # the ircd throws harmless warnings for missing nicknames, and duplicate hosts

        foreach my $nick (keys %{ $vanity })
            {
            set_host($SERV, $nick, $vanity->{$nick});
            }
        }
    elsif ($data =~ /^delete (\S+?)$/)
        {
        my $nick = lc $1;

        delete $vanity->{$nick};
        save_vanity();

        sigh "deleted $nick";
        }
    elsif ($data =~ /^(\S+?) (\S+)$/)
        {
        my $nick = lc $1;
        my $vain_host = $2;

        set_host($SERV, $nick, $vain_host);

        $vanity->{$nick} = $vain_host;
        save_vanity();
        }
    else
        {
        show_vanity();
        }
    }

####################################################################################################

sub show_vanity()
    {
    sigh '-' x 50;

    my $len = 0; map { $len = $_ if $_ > $len } map { length } keys %{ $vanity };

    foreach my $nick (sort keys %{ $vanity })
        {
        sigh sprintf "\%${len}s\@%s" => $nick, $vanity->{$nick};
        }

    sigh '-' x 50;
    }

####################################################################################################

sub load_vanity()
    {
    if (my $data = read_file($VANITY_FILE, err_mode => 'quiet'))
        {
        $vanity = decode_json($data);
        }
    else
        {
        $vanity = { };

        sigh "reading $VANITY_FILE failed; starting with empty database";
        }
    }

####################################################################################################

sub save_vanity()
    {
    write_file($VANITY_FILE, encode_json $vanity);
    }

####################################################################################################

sub is_oper() { Irssi::active_server()->{server_operator} ? 1 : undef }
sub sigh(@)   { say "[vanity] ", @_                                   }

####################################################################################################
