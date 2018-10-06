use 5.18.1;
use strict;
use warnings;
use LWP::UserAgent();
use JSON qw/decode_json/;
binmode(STDOUT, ":utf8");

my $ua = LWP::UserAgent->new;
$ua->timeout(10);
$ua->ssl_opts( verify_hostname => 0 );

my $base_url = "https://sv2018.cvk.lv/pub/ElectionResults?";

my $version_key = "FUOXAvl4obyRJKecb9lU35TPn5smqdtqWYxsjlaPk0E=";


my $resp = $ua->post($base_url);

my %elected_parties_by_id;

if ($resp->is_success) {
    my $base_data = decode_json($resp->content);
    my $base_results = $base_data->{result}->{candidateLists};
    for my $result ( @$base_results ) {
        if ( $result->{validMarkCount}->{percentage} >= 5 ) {
            $elected_parties_by_id{$result->{number}} = $result;
        }
    }
    for my $region ( @{ $base_data->{childResults} } ) {
        my $max_in_region = $region->{location}->{deputyLimit};
        my @votes_for_seats;
        for my $party ( @{ $region->{candidateLists} } ) {
            if ( $elected_parties_by_id{$party->{number}} ) {
                my $votes = $party->{validMarkCount}->{count};
                for (my $i =0; $i < $max_in_region; $i++) {
                    push @votes_for_seats, { number => $party->{number}, votes => $votes/(2*$i+1) };
                }
            } 
        }
        my @sorted_votes = sort { $b->{votes} <=> $a->{votes} } @votes_for_seats;
        for (my $i = 0; $i < $max_in_region; $i++ ) {
            my $vote = $sorted_votes[$i];
            $elected_parties_by_id{$vote->{number}}->{seats}++;
        }
    }

    my $longest_party_name = 0;
    for ( values %elected_parties_by_id ) {
        $longest_party_name = $longest_party_name < length $_->{name} ? length $_->{name} : $longest_party_name;
    }

    for my $party ( sort { $b->{seats} <=> $a->{seats} } values %elected_parties_by_id ) {
        my $padding = $longest_party_name - length $party->{name};
        say $party->{name} . (" "x$padding) 
            . " - " . ($party->{seats} > 10 ? $party->{seats} : " ".$party->{seats}) 
            . ' - ' . ($party->{validMarkCount}->{percentage} > 10 ? $party->{validMarkCount}->{percentage} : ' '.$party->{validMarkCount}->{percentage}) . '%';
    }
} else {
    die $resp->status_line;
}
