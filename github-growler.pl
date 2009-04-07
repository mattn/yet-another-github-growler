use strict;
use warnings;
use lib qw/lib/;
use Encode;
use URI;
use LWP::Simple;
use XML::Feed;
use XML::Feed::Deduper;
use HTML::TreeBuilder::XPath;
use GNTP::Growl;
use YAML;

my $dir = '/tmp/yet-another-github-growler';
if ($^O eq "MSWin32") {
    binmode STDOUT, ":encoding(cp932)";
    $dir = 'c:/temp/yet-another-github-growler';
}

chomp(my $user  = `git config github.user`);
chomp(my $token = `git config github.token`);

mkdir $dir, 0777 unless -e $dir;
mkdir "$dir/icon", 0777 unless -e "$dir/icon";
my $deduper = XML::Feed::Deduper->new(
    path => "$dir/feed.db"
);

my $growl = GNTP::Growl->new(
	AppName => 'Yet Another Github Growler',
	Password => 'secret',
);
$growl->register([
	{ Name => 'Notify', Enabled => 'True' },
]);
my $tree = HTML::TreeBuilder::XPath->new;

while (1) {
    my $uri = URI->new( "http://github.com/$user.private.atom?token=$token" );
    my $feed = eval { XML::Feed->parse( $uri ) };
    unless ($feed) { warn $@; next; }

    my $i;
    for my $entry ($deduper->dedup($feed->entries)) {
		warn get_icon($entry->author),"\n";
		$growl->notify(
			Event   => 'Notify',
			Title   => encode_utf8($entry->title),
			Message => encode_utf8(get_text($entry->content->body)),
			Icon    => get_icon($entry->author),
		);
        last if $i++ > 10;
    }
    sleep 5;
}

sub get_text {
    $tree->parse(shift || '');
    my $text = $tree->findvalue( '//div[contains(concat(" ",@class," ")," message ")]' );
    $text =~ s/^\s*[0-9a-f]{40}\s*//;
	return $text;
}

sub get_icon {
    my $name = shift;
    my $icon = (glob("$dir/icon/$name\.*"))[-1] || '';
	return $icon if $icon;

    use Web::Scraper;
    my $scraper = scraper {
        process "#profile_name", name => 'TEXT';
        process ".identity img", avatar => [ '@src', sub {
            my $suffix = (split(/\./, $_))[-1];
            my $path = "$dir/icon/$name.$suffix";
            LWP::Simple::mirror($_, $path);
			return $path;
        } ];
    };
    $icon = eval { $scraper->scrape(URI->new("http://github.com/$name")) } || {};
    return $icon->{avatar};
}
