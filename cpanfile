requires 'perl',        '5.010';
requires 'Mojolicious', '7.08';
requires 'Minion',      '6.0';
requires 'Ouch',        '0.0409';
requires 'Log::Any',    '1.042';
requires 'Bot::ChatBots';

on test => sub {
   requires 'Test::More',              '0.88';
   requires 'Path::Tiny',              '0.096';
   requires 'Minion::Backend::SQLite', '0.007';
};

on develop => sub {
   requires 'Path::Tiny',        '0.096';
   requires 'Template::Perlish', '1.52';
};
