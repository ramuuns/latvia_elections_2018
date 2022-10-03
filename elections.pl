use 5.18.1;
use strict;
use warnings;
use JSON qw/decode_json/;
binmode(STDOUT, ":utf8");

my $act_json = `curl -s 'https://sv2022.cvk.lv/pub/Api/749764b5b2834d9faa68e358fca4d803/Activity/root' -X 'GET' -H 'Pragma: no-cache' -H 'Accept: application/json, text/plain, */*' -H 'Accept-Language: en-GB,en;q=0.9' -H 'Accept-Encoding: gzip, deflate, br' -H 'Cache-Control: no-cache' -H 'Host: sv2022.cvk.lv' -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.4 Safari/605.1.15' -H 'Connection: keep-alive' -H 'Referer: https://sv2022.cvk.lv/pub/aktivitate' -H 'Cookie: _ga=GA1.1.574142751.1664448706; _ga_J7QT0KKPGY=GS1.1.1664692271.9.1.1664694002.0.0.0; _gid=GA1.2.1301026999.1664640285; sv2022.cvk.lv-cookies-accepted=true' -H 'AjaxRequest: true' -H 'AntiXsrfToken: '`;

my $json = `curl -s 'https://sv2022.cvk.lv/pub/Api/feaa9cf53f3b4bc783b44f4cdd6602e3/ElectionResults' -X 'GET' -H 'Pragma: no-cache'  -H 'Accept: application/json, text/plain, */*' -H 'Accept-Language: en-GB,en;q=0.9' -H 'Accept-Encoding: gzip, deflate, br' -H 'Cache-Control: no-cache' -H 'Host: sv2022.cvk.lv' -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.4 Safari/605.1.15' -H 'Connection: keep-alive' -H 'Referer: https://sv2022.cvk.lv/pub/velesanu-rezultati' -H 'Cookie: _ga=GA1.1.574142751.1664448706; _ga_J7QT0KKPGY=GS1.1.1664649671.5.1.1664652308.0.0.0; _gid=GA1.2.1301026999.1664640285; sv2022.cvk.lv-cookies-accepted=true' -H 'AjaxRequest: true' -H 'AntiXsrfToken: '`;

my %elected_parties_by_id;
if ($json) {
    my $act_data = decode_json($act_json);
    my %voters_per_deparment_id = map {
        $_->{department}->{id} => $_->{totalStatistic}->{count}
    } @{ $act_data->{activities} };

    my $base_data = decode_json($json);
 
    my $base_results = $base_data->{departmentResults}->[0]->{candidateLists};
    for my $result ( @$base_results ) {
        if ( $result->{totalValidMarkCount}->{percentage} >= 5 ) {
            $elected_parties_by_id{$result->{number}} = $result;
        }
    }

    my $longest_party_name = 0;
    for ( values %elected_parties_by_id ) {
        $longest_party_name = $longest_party_name < length $_->{name} ? length $_->{name} : $longest_party_name;
    }

    for my $region ( @{ $base_data->{departmentResults} } ) {

        my $max_in_region = $region->{department}->{deputyCount};
        my @votes_for_seats;
        for my $party ( @{ $region->{candidateLists} } ) {
            if ( $elected_parties_by_id{$party->{number}} ) {
                my $votes = $party->{validMarkCount}->{count};
                # Uncomment and play around if you want to see how much additional votes would impact results
                # if ( $party->{number} == 15 && $region->{department}->{id} eq "riga" ) {
                #     $votes += 4767;
                # }
                for (my $i =0; $i < $max_in_region; $i++) {
                    push @votes_for_seats, { number => $party->{number}, votes => $votes/(2*$i+1) };
                }
            } 
        }
        my %elected_this_region;
        my @sorted_votes = sort { $b->{votes} <=> $a->{votes} } @votes_for_seats;
        for (my $i = 0; $i < $max_in_region; $i++ ) {
            my $vote = $sorted_votes[$i];
            $elected_this_region{$vote->{number}}++;
            $elected_parties_by_id{$vote->{number}}->{seats}++;
        }
        say $region->{department}->{name} . " " . sprintf("%.2f", ( $region->{votedVoterCount}->{count} / $voters_per_deparment_id{$region->{department}->{id}} ) * 100 ) . "%";
        say "";
        my @sorted_elected_this_region = sort { $b->{votes} <=> $a->{votes} } map +{ key => $_, votes => $elected_this_region{$_} }, keys %elected_this_region;

        for my $p ( @sorted_elected_this_region ) {
            my $party = $elected_parties_by_id{$p->{key}};
            my $padding = $longest_party_name - length $party->{name};
            say $party->{name} . (" "x$padding) . ' - ' . $p->{votes};
        }
        say "";
    }


    for my $party ( sort { $b->{seats} <=> $a->{seats} } grep { $_->{seats} } values %elected_parties_by_id ) {
        my $padding = $longest_party_name - length $party->{name};
        say $party->{name} . (" "x$padding) 
            . " - " . ($party->{seats} >= 10 ? $party->{seats} : " ".$party->{seats}) 
            . ' - ' . ($party->{totalValidMarkCount}->{percentage} >= 10 ? $party->{totalValidMarkCount}->{percentage} : ' '.$party->{totalValidMarkCount}->{percentage}) . '%';
    }
} else {
    die $json;
}
