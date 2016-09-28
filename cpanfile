requires 'perl',        '5.010';
requires 'Mojolicious', '7.08';
requires 'Minion',      '6.0';

on test => sub {
   requires 'Test::More', '0.88';
   requires 'Path::Tiny', '0.096';
};

on develop => sub {
   requires 'Path::Tiny',        '0.096';
   requires 'Template::Perlish', '1.52';
};
