#!/usr/bin/perl

use strict;
use warnings;

use Tk;
use Tk::DialogBox;

$| = 1;

unless(@ARGV == 1) {
  print STDERR "usage: ./filter.pl <rule-file>\n";
  die;
}

my @validPatterns;

my $patterns = $ARGV[0];
if(not -e $patterns) {
  open PATTERNS, '>', $patterns or die "cannot open $patterns: $!";
  close PATTERNS;
}

open PATTERNS, '<', $patterns or die "cannot open $patterns: $!";
while(my $line = <PATTERNS>) {
  chomp $line;
  push @validPatterns, qr($line);
}
close PATTERNS;

my $mayRun = 1;

my $mw = MainWindow->new();
$mw->withdraw();

while(my $line = <STDIN>) {
  chomp $line;
  warn $line;
  if($line =~ /^CONTINUE/) {
    print $mayRun? "\n": "Nuke it!\n";
  } else {
    my ($applicableRule) = grep { $line =~ $_ } @validPatterns;
    if($mayRun = defined $applicableRule) {
      warn "Auto allowed by " . $applicableRule;
    } else {
      my $dialog = $mw->DialogBox (-title => "Unexpected syscall requested. What now?",
                                   -buttons => ["Allow", "Create new rule (upper)", "Create new rule (lower)", "Kill"]);
      $dialog->add('Label', -text => $line)->pack();
      my $rule = $dialog->add('Text');
      my $proposal = $line;
      $proposal =~ s/\|/\\|/g;
      $proposal =~ s/\+/\\+/g;
      $proposal =~ s/\*/\\*/g;
      $proposal =~ s/\?/\\?/g;
      $proposal =~ s/^\[pid\s+\d+\]/]/g;
      $proposal =~ s/\//\\\//g;
      $proposal =~ s/\[/\\[/g;
      $proposal =~ s/\]/\\]/g;
      $proposal =~ s/\(/\\(/g;
      $proposal =~ s/\)/\\)/g;
      $proposal =~ s/0x[a-f0-9]+/0x[a-f0-9]+/g;
      $proposal =~ s/\d{3,}/\\d+/g;
      $proposal =~ s/\d+</\\d+</g;
      $rule->Contents($proposal);
      $rule->pack();

      my $stringAbstractRule = $dialog->add('Text');
      my $stringAbstractProposal = $proposal;
      $stringAbstractProposal =~ s/"[^"]+"/"[^"]*"/g;
      $stringAbstractRule->Contents($stringAbstractProposal);
      $stringAbstractRule->pack();

      my $item = $dialog->Show();
      if($item eq "Allow") {
        $mayRun = 1;
      } elsif($item eq "Create new rule (upper)") {
        my $newRule = $rule->Contents();
        my $matches;
        eval {
          $matches = $line =~ /$newRule/;
        };
        redo if $@ or not $matches;
        push @validPatterns, qr($newRule);
        open PATTERNS, '>>', $patterns or die "cannot open $patterns: $!";
        print PATTERNS "$newRule\n";
        close PATTERNS;
        $mayRun = 1;
      } elsif($item eq "Create new rule (lower)") {
        my $newRule = $stringAbstractRule->Contents();
        my $matches;
        eval {
          $matches = $line =~ /$newRule/;
        };
        redo if $@ or not $matches;
        push @validPatterns, qr($newRule);
        open PATTERNS, '>>', $patterns or die "cannot open $patterns: $!";
        print PATTERNS "$newRule\n";
        close PATTERNS;
        $mayRun = 1;
      }
    }
  }
}
