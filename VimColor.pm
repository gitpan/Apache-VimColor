package Apache::VimColor;

use strict;
use warnings;
use vars qw/$VERSION/;

use Apache::Const qw/:common/;
use Apache::RequestRec;
use Apache::RequestIO;
use Apache::RequestUtil;
use Text::VimColor;

$VERSION = '1.00';

=head1 NAME

B<Apache::VimColor> - Apache mod_perl PerlHandler for syntax highlighting in
HTML.

=head1 SYNOPSIS

This module requires B<mod_perl2> (see L<http://perl.apache.org/>) and
B<Text::VimColor>.

The apache configuration neccessary might look a bit like this:

  # in httpd.conf (or any other apache configuration file)
  <Location /source>
    SetHandler		perl-script
    PerlHandler		Apache::VimColor

    # Below here is optional
    PerlSetVar  AllowDownload  "True"
    PerlSetVar  TabSize        8
    PerlSetVar  StyleSheet     "http://domain.com/stylesheet.css"
  </Location>

=head1 DESCRIPTION

This apache handler converts text files in syntax highlighted HTML output using
L<Text::VimColor>. If allowed by the configuration the visitor can also
download the text-file in it's original form.

=cut

our $Position = 0;

return (1);

sub escape_html ($)
{
	$_ = shift;

	s/\&/&amp;/g;
	s/</&lt;/g;
	s/>/&gt;/g;
	s/"/&quot;/g;

	s#\n#<br />\n#g;
	s/(\s\s+)/'&nbsp;' x length ($1)/ge;

	return ($_);
}

sub escape_tabs ($$)
{
	my $value   = shift;
	my $tabstop = shift;
	my $retval = '';

	$value =~ s/\r//g;

	while ($value =~ s/^([^\n\t]*)([\n\t])//)
	{
		$retval .= $1;
		$Position += length ($1);

		if ($2 eq "\n")
		{
			$retval .= "\n";
			$Position = 0;
		}
		else
		{
			my $num =  $tabstop - ($Position % $tabstop);
			$retval .= ' 'x$num;
			$Position += $num;
		}
	}

	$retval .= $value;
	$Position += length ($value);

	return ($retval);
}

sub handler
{
	my $req = shift;
	my $filename = $req->filename ();
	my $dl = 0;
	my $dl_ok = 0;
	my $vim;
	my $elems;
	my $cssfile = '';
	my $tabstop  = 8;

=head1 CONFIGURATION DIRECTIVES

All features of the this PerlHandler can be set in the apache configuration
using the I<PerlSetVar> directive. For example:

    PerlSetVar	AllowDownload	true	# inside <Files>, <Location>, ...
					# apache directives

=over 4

=item AllowDownload

Setting this option to B<true> will allow plaintext downloads of the files. A
link will be included in the output.

=cut

	if ($req->dir_config ('AllowDownload'))
	{
		my $conf = lc ($req->dir_config ('AllowDownload'));

		if (($conf eq 'on') or ($conf eq 'true')
				or ($conf eq 'yes'))
		{
			$dl_ok = 1;
		}
	}

=item TabStop

Sets the width of one tab symbol. The default is eight spaces.

=cut

	if ($req->dir_config ('TabStop'))
	{
		my $tmp = $req->dir_config ('TabStop');
		$tmp =~ s/\D//g;
		$tabstop = $tmp if ($tmp);
	}

=item StyleSheet

If you want to include a custom stylesheet you can set this option. The string
will be included in the html-output as-is, you will have to take care of
relative filenames yourself.

All highlighted text is withing a C<span>-tag with one of the following
classes:

    Comment
    Constant
    Error
    Identifier
    PreProc
    Special
    Statement
    Todo
    Type
    Underlined

=cut

	if ($req->dir_config ('StyleSheet'))
	{
		$cssfile = $req->dir_config ('StyleSheet');
	}

=back

=cut

	if ($req->args ())
	{
		my %args = $req->args ();

		if (exists ($args{'download'})
				and ($dl_ok))
		{
			$req->content_type ("text/perl-script");
			$dl = 1;
		}
		else
		{
			$req->content_type ("text/html");
		}
	}
	else
	{
		$req->content_type ("text/html");
	}

	#$req->send_http_header ();

	if ($req->header_only ())
	{
		return (OK);
	}

	if ($dl)
	{
		return ($req->sendfile ($filename));
	}

	$req->print (<<HEADER);
<html>
	<head>
		<title>$filename</title>
HEADER
	$req->print ($cssfile ? qq(\t\t<link rel="stylesheet" type="text/css" href="$cssfile" />\n) : <<HEADER);
		<style type="text/css">
		<!--
		body { background-color: black; color: white; }
		div.fixed { font-family: monospace; border: 1px solid silver; padding: 1ex; }
		a { display: block; width: auto; padding: 0.5ex; background-color: silver; color: black; }
		
		span.Comment { color: blue; }
		span.Constant { color: red; }
		span.Identifier { color: cyan; }
		span.Statement { color: yellow; }
		span.PreProc { color: fuchsia; }
		span.Type { color: lime; }
		span.Special { color: fuchsia; }
		span.Underlined { color: fuchsia; text-decoration: underline; }
		span.Error { background-color: red; color: white; font-weight: bold; }
		span.Todo { background-color: yellow; color: black; }
		-->
		</style>
HEADER
	$req->print (<<HEADER);
	</head>

	<body>
		<div class="fixed">
HEADER

	$vim = new Text::VimColor (file => $filename);
	$elems = $vim->marked ();

	for (@$elems)
	{
		my $type  = $_->[0];
		my $value = $_->[1];
		$value = escape_tabs ($value, $tabstop);
		$value = escape_html ($value);

		if ($type)
		{
			$req->print (qq(<span class="$type">$value</span>));
		}
		else
		{
			$req->print ($value);
		}
	}

	$req->print ("\t\t</div>\n");
	$req->print (qq(\t\t<a href=") . $req->uri () . qq(?download">Download this file</a>\n)) if ($dl_ok);
	$req->print ("\t</body>\n</html>\n");

	return (OK);
}

=head1 SEE ALSO

L<perl(1)>, L<mod_perl(3)>, L<Apache(3)>, L<Text::VimColor|Text::VimColor>

=head1 AUTHOR

  Florian octo Forster
  octo(at)verplant.org
  http://verplant.org/

=head1 COPYRIGHT

Copyright (c) 2005 Florian Forster.

All rights reserved. This package is free software; you can redistribute it
	and/or modify it under the same terms as Perl itself.

=cut
