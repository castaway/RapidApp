package RapidApp::Web1RenderContext;
use Moose;
use RapidApp::Include 'perlutil';

use RapidApp::Web1RenderContext::RenderFunction;
use RapidApp::Web1RenderContext::RenderHandler;
use RapidApp::Web1RenderContext::Renderer;

our $DEFAULT_RENDERER= RapidApp::Web1RenderContext::RenderFunction->new(\&data2html);

has '_css_files' => ( is => 'rw', isa => 'HashRef', default => sub {{}} );
has '_js_files'  => ( is => 'rw', isa => 'HashRef', default => sub {{}} );
has 'header_fragments' => ( is => 'rw', isa => 'ArrayRef', default => sub {[]} );
has 'body_fragments' => ( is => 'rw', isa => 'ArrayRef', default => sub {[]} );
has 'renderer'  => ( is => 'rw', isa => 'RapidApp::Web1RenderContext::Renderer', lazy => 1, default => sub { $DEFAULT_RENDERER });

sub BUILD {
	my $self= shift;
}

sub incCSS {
	my ($self, $cssUrl)= @_;
	$self->_css_files->{$cssUrl}= undef;
}

sub getCssIncludeList {
	my $self= shift;
	return keys %{$self->_css_files};
}

sub incJS {
	my ($self, $jsUrl)= @_;
	$self->_js_files->{$jsUrl}= undef;
}

sub getJsIncludeList {
	my $self= shift;
	return keys %{$self->_js_files};
}

sub addHeaderLiteral {
	my ($self, @text)= @_;
	push @{$self->header_fragments}, @text;
}

sub getHeaderLiteral {
	my $self= shift;
	return join("\n", @{$self->header_fragments});
}

sub getBody {
	my $self= shift;
	return join('', @{$self->body_fragments});
}

sub write {
	my $self= shift;
	push @{$self->body_fragments}, @_;
}

sub escHtml {
	my ($self, $text)= @_;
	scalar(@_) > 1 or $text= $self; # can be called as either object, package, or plain function
	$text =~ s/&/&amp;/g;
	$text =~ s/</&lt;/g;
	$text =~ s/>/&gt;/g;
	$text =~ s/"/&quot;/g;
	return $text;
}

sub render {
	my ($self, $data)= @_;
	return $self->renderer->renderAsHtml($self, $data);
}

sub data2html {
	my ($self, $obj)= @_;
	$self and $self->incCSS('/static/rapidapp/css/data2html.css');
	return _data2html(@_, {});
}

sub _data2html {
	my ($self, $obj, $seenSet)= @_;
	if (!ref $obj) {
		$self->write((defined $obj? escHtml("'$obj'") : "undef")."<br/>\n");
	} elsif (blessed $obj) {
		$self->write('<span class="dump-blessed-clsname">'.(ref $obj).'</span><div class="dump-blessed">');
		$self->_ref2html(reftype($obj), $obj, $seenSet),
		$self->write('</div>');
	} else {
		$self->_ref2html(ref ($obj), $obj, $seenSet);
	}
}

sub _ref2html {
	my ($self, $refType, $obj, $seenSet)= @_;
	if (exists $seenSet->{$obj}) {
		return $self->write("(seen previously) $obj");
	}
	$seenSet->{$obj}= undef;
	if ($refType eq 'HASH') {
		$self->_hash2html($obj, $seenSet);
	} elsif ($refType eq 'ARRAY') {
		$self->_array2html($obj, $seenSet);
	} elsif ($refType eq 'SCALAR') {
		$self->write('<span class="dump-deref">[ref]</span>'.escHtml($$obj)."<br/>\n");
	} elsif ($refType eq 'REF') {
		$self->write('<span class="dump-deref">[ref]</span>');
		$self->_data2html($$obj, $seenSet);
	} else {
		$self->write(escHtml("$obj")."<br/>\n");
	}
}

sub _hash2html {
	my ($self, $obj, $seenSet)= @_;
	$self->write('<div class="dump-hash">');
	my $maxKeyLen= 0;
	my @keys= sort keys %$obj;
	for my $key (@keys) {
		$maxKeyLen= length($key) if length($key) > $maxKeyLen;
	}
	for my $key (sort keys %$obj) {
		$self->write(sprintf("\n<span class='key'>%*s</span> ",-$maxKeyLen, $key));
		$self->_data2html($obj->{$key}, $seenSet);
	}
	$self->write('</div>');
}

sub _array2html {
	my ($self, $obj, $seenSet)= @_;
	$self->write('<table class="dump-array">');
	my $i= 0;
	for my $item (@$obj) {
		$self->write(sprintf("\n<tr><td class='key'>%d -</td><td>", $i++));
		$self->_data2html($item, $seenSet);
		$self->write('</td></tr>');
	}
	$self->write('</table>');
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
