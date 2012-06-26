#!./perl

# Checks if the parser behaves correctly in edge cases
# (including weird syntax errors)

BEGIN {
    require './test.pl';
}

plan (tests => 65714);

use 5.016;
use utf8;
use open qw( :utf8 :std );

# Checking that at least some of the special variables work
for my $v (qw( ^V ; < > ( ) {^GLOBAL_PHASE} ^W _ 1 4 0 [ ] ! @ / \ = )) {
    local $@;
    evalbytes "\$$v;";
    is $@, '', "No syntax error for \$$v";
    
    local $@;
    eval "use utf8; \$$v;";
    is $@, '', "No syntax error for \$$v under use utf8";
}

# Checking if the Latin-1 range behaves as expected, and that the behavior is the
# same whenever under strict or not.
for ( 0x80..0xff ) {
    no warnings 'closure';
    my $chr = chr;
    utf8::downgrade($chr);
    if ($chr !~ /\p{XIDS}/) {
        local $@;
        evalbytes "no strict; \$$chr = 1";
        like $@,
            qr/\QIllegal character "$chr" (\E[^()]+\Q) in variable name/,
            sprintf("\\x%02x, part of the latin-1 range, is illegal as a length-1 variable", $_);

        utf8::upgrade($chr);
        local $@;
        eval "no strict; use utf8; \$$chr = 1";
        like $@,
            qr/\QIllegal character "$chr" (\E[^()]+\Q) in variable name/,
            sprintf("\\x%02x, part of the latin-1 range, is illegal as a length-1 variable under use utf8", $_);
    }
    else {
        {
            no utf8;
            local $@;
            evalbytes "no strict; \$$chr = 1";
            is($@, '', sprintf("\\x%02x, =~ \p{XIDS}, latin-1, no utf8, no strict, is a valid length-1 variable", $_));

            local $@;
            evalbytes "use strict; \$$chr = 1";
            like($@,
                qr/Global symbol "\$$chr" requires explicit package name/,
                "...but has to be required under strict."
                );
        }
        {
            use utf8;
            my $u = $chr;
            utf8::upgrade($u);
            local $@;
            eval "no strict; \$$u = 1";
            is($@, '', sprintf("\\x%02x, =~ \p{XIDS}, UTF-8, use utf8, no strict, is a valid length-1 variable", $_));

            local $@;
            eval "use strict; \$$u = 1";
            like($@,
                qr/Global symbol "\$$u" requires explicit package name/,
                "...but has to be required under strict."
                );
        }
    }
}

{
    use utf8;
    eval "my \$c\x{327} = 1"; # c + cedilla
    is($@, '', "ASCII character + combining character works as a variable name");
}

# From Tom Christiansen's 'highly illegal variable names are now accidentally legal' mail
for my $chr (
      "\N{EM DASH}", "\x{F8FF}", "\N{POUND SIGN}", "\N{SOFT HYPHEN}",
      "\N{THIN SPACE}", "\x{11_1111}", "\x{DC00}", "\N{COMBINING DIAERESIS}",
      "\N{COMBINING ENCLOSING CIRCLE BACKSLASH}",
   )
{
   no warnings 'non_unicode';
   local $@;
   eval "\$$chr = 1; \$$chr";
   like($@,
        qr/\QIllegal character "$chr" (\E[^()]+\Q) in variable name/,
        sprintf("\x{%04x} is illegal for a lenght-one identifier", ord $chr)
       );
}

for my $i (0x100..0xffff) {
   my $chr = chr($i);
   local $@;
   eval "my \$$chr = q<test>; \$$chr;";
   if ( $chr =~ /^\p{_Perl_IDStart}$/ ) {
      is($@, '', sprintf("\\x{%04x} is XIDS, works as a length-1 variable", $i));
   }
   else {
      like($@,
           qr/\QIllegal character "$chr" (\E[^()]+\Q) in variable name/,
           sprintf("\\x{%04x} isn't XIDS, illegal as a length-1 variable", $i),
          )
   }
}
