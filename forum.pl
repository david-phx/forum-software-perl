#!/usr/bin/perl
##############################################################################
# Dzhan's Forum                              Version 1.0a                    #
# Copyright (c) 2001 by David Asatrian       http://www.dzhan.ru/            #
# Created: 18/08/2001                        Last modified: 15/09/2002       #
##############################################################################
# Параметры (везде метод GET, кроме специально оговоренных):
#
#   Расположение:
#     room=название комнаты
#     p=номер страницы
#     msg=номер сообщения
#
#   Сортировка:
#     ac=1                  (сортировка от первых сообщений к последним)
#
#   Действия:
#     add=1                 (ответить или начать новую дискуссию)
#       cite=1              (цитировать при ответе)
#     post=1                (добавляем сообщение : POST)
#       edited=1            (добавляемое сообщение - редактированное : POST)
#     admin=1               (включить функции администратора)
#
#   Администрирование:
#       edit=1              (редактировать сообщение)
#       remove=1            (удалить сообщение)
#       out=1               (выйти из режима администрирования)
##############################################################################
# Настройки:

$data_dir = "../data";
$icon_dir = "../images";

$title = "Тестовый Форум";
$description = "Тестовый Форум - Dzhan's Forum";
$keywords = "тест, форум, джан";
$hp_title = " Джан.Ру ";
$hp_url = "http://www.dzhan.ru/";
$show_rooms = 1;
%rooms = ("private" => "Частная комната",
          "flame" => "Флеймы",
          "admin" => "Административные вопросы");
$name_color = "";
$name_bold = 1;
$name_italic = 0;
$subject_color = "";
$subject_bold = 0;
$subject_italic = 1;
$namesubject_font = "Arial, sans-serif";
$namesubject_size = "2";
$body_tag = "<body bgcolor=\"\#FFFFFF\" vlink=\"\#000080\" link=\"\#0000FF\" alink=\"\#FF0000\" text=\"\#000000\">";
$top_html = "../top.html";
$bottom_html = "../bottom.html";
$css_url = "";
$indent = 8;
$page_threads = 20;
$allow_cite = 1;
$show_icons = 1;
$deny_ip = "../ban-ip.txt";
$deny_ip_html = "../ban-ip.html";

##############################################################################
# Ниже этого ничего не редактировать!

use CGI qw/:standard/;
#use CGI::Carp(fatalsToBrowser);

if (param('admin')) {
  &set_admin;
} elsif (param('out')) {
  &exit_admin;
} else {
  &check_if_admin;
  &init;

  if (param('msg')) {

    unless ((param('msg') =~ /^\d+?(\.|$)/) and (-e "$data_dir/".param('msg'))) {
      &error ("Ошибка!"." Неверный параметр: \"msg=".param('msg')."\".");
    }

    if (param('edit') and $admin) {
      &admin_edit_msg(param('msg'));
    } elsif (param('remove') and $admin) {
      &admin_remove_msg(param('msg'));
    } else {
      &print_message(param('msg'));
    }

  } elsif (param('add')) {
    &add_new_thread;
  } elsif (param('post')) {
    &add_message;
  } else {
    &print_msg_list;
  }

}

##############################################################################
# Начальная инициализация
##############################################################################

sub init {
  print "Content-type: text/html\n\n";

  if ($show_rooms) {
    foreach $room (keys %rooms) { 
      unless (-e "$data_dir"."/"."$room") { mkdir "$data_dir"."/"."$room"; }
    }
  }

  if (param('room')) {
    unless (exists($rooms{param('room')})) {
      &error ("Ошибка!"." Неверный параметр: \"room=".param('room')."\".");
    }
    $data_dir = $data_dir."/".param('room');
  }

  opendir (DIR, $data_dir) || die "Error opening directory \"$data_dir\": $!";
  @messages = grep {-f "$data_dir/$_"} readdir DIR;
  @messages = grep (/^\d/, @messages);
  closedir DIR;

  $self_url = url(-relative=>1);
}

##############################################################################
# Печатаем список сообщений
##############################################################################

sub print_msg_list {
  my @threads = grep (/^\d+$/, @messages);
  @threads = sort ({&cmp_msgs($a, $b)} @threads);
  if (!param('ac')) { @threads = reverse @threads; }

  my $num_pages = (($#threads+1)/$page_threads);
  if (int($num_pages) < $num_pages) { $num_pages = int(++$num_pages); }

  my $page = 1;
  $page = param('p') if param('p');
  if ($page =~ /\D/) {
    &error ("Ошибка!"." Неверный параметр: \"p=".param('p')."\".");
  }

  if (($page*$page_threads)-1 <= $#threads) {
    @threads = @threads[($page-1)*$page_threads..($page*$page_threads)-1];
  } else {
    @threads = @threads[($page-1)*$page_threads..$#threads];
  }
  
  my $thread_root;
  my $thread_message;
  my @thread;

  &print_html_header;

  foreach $thread_root (@threads) {
    @thread = grep (/^$thread_root(\.|$)/, @messages);
    @thread = sort({&cmp_msgs($a, $b)} @thread);
    foreach $thread_message (@thread) {
      &print_namesubject ($thread_message);
    }
  }

  print qq(<p>Страницы: &nbsp;);

  for ($i=1; $i<=$num_pages; $i++) {
    if ($page == $i) {
      print qq(<b>$page</b> );
    } else {
      print qq(<a href="$self_url?);
      if (param('room')) {                 # сохраняем комнату, если есть
        print qq(room=);
        print param('room');
        print ("&");
      }
      print qq(p=$i);
      print qq(&ac=1) if param('ac');      # сохраняем сортировку, если есть
      print qq(">$i</a> );
    }
  }

  if ($page < $num_pages) {
    my $next_page = ++$page;
    print qq(<a href="$self_url?);
    if (param('room')) {                   # сохраняем комнату, если есть
      print qq(room=);
      print param('room');
      print ("&");
    }
    print qq(p=$next_page);
    print qq(&ac=1) if param('ac');        # сохраняем сортировку, если есть
    print qq(">&gt;&gt;&gt;</a>);
  }

  if ($show_rooms) {
    print qq(<p>Комнаты: );
    if (!param('room')) {
      print qq(<b>Главная</b> );
    } else {
      print qq(<a href="$self_url">Главная</a> );
    }
    foreach $room (keys %rooms) { 
      if (param('room') eq $room) {
        print qq( <b>$rooms{$room}</b> );
      } else {
        print qq(&nbsp;<a href="$self_url?room=$room">$rooms{$room}</a> );
      }
    }
  }

  &print_html_footer;
}

##############################################################################
# Печатаем сообщение
##############################################################################

sub print_message {
  my $file = $_[0];
  my $thread_num = substr($file, 0, index($file, ".")) if (index($file, ".") != -1);
  if (!$thread_num) { $thread_num = $file; }

  open (FILE, "$data_dir/$file") || die "Error opening file \"$data_dir/$file\": $!";
  chomp(my $name = <FILE>);
  chomp(my $email = <FILE>);
  chomp(my $ip = <FILE>);
  chomp(my $subject = <FILE>);
  chomp(my $time = <FILE>);
  chomp(my $icon = <FILE>);

  &print_html_header ($subject);

  print qq(<hr size="1" noshade>\n);
  print $thread_num, ".&nbsp;";

  if ($icon and $show_icons) {
    print qq(<img src="$icon_dir/$icon.gif" width=15 height=15 border=0 alt="$icon">&nbsp;);
  }

  print "<font" if ($namesubject_font or $namesubject_size);
  print " face=\"$namesubject_font\"" if $namesubject_font;
  print " size=\"$namesubject_size\"" if $namesubject_size;
  print ">" if ($namesubject_font or $namesubject_size);

  print "<a href=\"mailto:$email\">" if $email;
  print "<b>" if $name_bold;
  print "<i>" if $name_italic;
  print "<font color=\"$name_color\">" if $name_color;
  print "$name";
  print "</font>" if $name_color;
  print "</i>" if $name_italic;
  print "</b>" if $name_bold;
  print "</a>" if $email;

  print ":\n";

  print "<b>" if $subject_bold;
  print "<i>" if $subject_italic;
  print "<font color=\"$subject_color\">" if $subject_color;
  print "$subject";
  print "</font>" if $subject_color;
  print "</i>" if $subject_italic;
  print "</b>" if $subject_bold;

  print "</font>" if ($namesubject_font or $namesubject_size);
  print "<br>\n\n";

  print "<p>";

  my $temp;

  while (<FILE>) {
    $temp = $_;
    chomp ($temp);
    $temp =~ s/http:\/\/\S+/<a href="$&" target=_blank>$&<\/a>/g; # check if URL
    $temp =~ s/ftp:\/\/\S+/<a href="$&" target=_blank>$&<\/a>/g;  # check if URL
    if ($temp =~ /^&gt;/) { $temp = "<i>".$temp."</i>"; }       # check if quote
    print $temp, "<br>\n";
  }

  close FILE;

  print ("\n<p><i>");
  print print_date($time)."</i>";

  if ($admin) {
    print "<br>\n[ <b>IP</b>: $ip ]" if $ip;
  }

  print ("<br>\n\n");

  print qq(<hr size="1" noshade>\n);

  print qq(<b><a href="$self_url?);
  if (param('room')) {
    print qq(room=);
    print param('room');
    print ("&");
  }
  print qq(msg=$file&add=1);
  print qq(&ac=1) if (param('ac'));
  print qq(">Ответить</a></b> );

  if ($allow_cite) {
    print qq([<b><a href="$self_url?);
    if (param('room')) {
      print qq(room=);
      print param('room');
      print ("&");
    }
    print qq(msg=$file&add=1&cite=1);
    print qq(&ac=1) if (param('ac'));
    print qq(">с цитированием</a></b>]\n);
  }

  print qq(&nbsp;<b><a href="$self_url);
  if (param('room')) {
    print qq(?room=);
    print param('room');
  }
  print qq(&ac=1) if (param('ac') and param('room'));
  print qq(?ac=1) if (param('ac') and !param('room'));

  print qq(">К списку</a></b>);

  if ($admin) {
    print qq(&nbsp; <b>[ &nbsp;);
    print qq(<a href="$self_url?);
    if (param('room')) {
      print qq(room=);
      print param('room');
      print ("&");
    }
    print qq(msg=$file&edit=1);
    print qq(&ac=1) if (param('ac'));
    print qq(">Редактировать</a>\n);

    print qq(&nbsp;<a href="$self_url?);
    if (param('room')) {
      print qq(room=);
      print param('room');
      print ("&");
    }
    print qq(msg=$file&remove=1);
    print qq(&ac=1) if (param('ac'));
    print qq(" onClick="return confirm('Внимание! При удалении сообщения удаляются также все ответы на него. Вы действительно хотите удалить сообщение?')");
    print qq(>Удалить</a>&nbsp; ]</b>);
  }

  print "<br>\n&nbsp;<br>\n";

  if (param('add')) {
    &print_add_form($file);
  } else {
    my @current_thread = grep (/^$thread_num(\.|$)/, @messages);
    @current_thread = sort({&cmp_msgs($a, $b)} @current_thread);

    my $message;

    foreach $message (@current_thread) {
      if ($message eq $file) {
        &print_namesubject ($message, "marked");
      } else {
        &print_namesubject ($message, "tree");
      }
    }

    my @threads = grep (/^\d+$/, @messages);
    @threads = sort ({&cmp_msgs($a, $b)} @threads);
    if (!param('ac')) { @threads = reverse @threads; }
    my $current_thread;
    for ($i=0; $i<=$#threads; $i++) {
      if ($thread_num == $threads[$i]) { $current_thread = $i; }
    }

    my $prev_thread = $threads[$current_thread-1] if ($current_thread != 0);
    my $next_thread = $threads[$current_thread+1] if ($current_thread != $#threads);

    print "<p>Переход по нитям: ";

    if ($prev_thread) {
      print qq(&nbsp; <a href="$self_url?);
      if (param('room')) {
        print qq(room=);
        print param('room');
        print ("&");
      }
      print qq(msg=$prev_thread);
      print qq(&ac=1) if (param('ac'));
      print qq(">$prev_thread &lt;&lt;&lt;</a>);
    }

    print "&nbsp; <b>$thread_num</b> &nbsp;";

    if ($next_thread) {
      print qq(<a href="$self_url?);
      if (param('room')) {
        print qq(room=);
        print param('room');
        print ("&");
      }
      print qq(msg=$next_thread);
      print qq(&ac=1) if (param('ac'));
      print qq(">&gt;&gt;&gt; $next_thread</a>);
    }
  }

  print "<p>\n";

  &print_html_footer;
}

##############################################################################
# Печатаем строчку с именем отрправителя и темой сообщения
##############################################################################
# Вызов: print_namesubject(FileName, ["marked"|"tree"])
# Где: "marked" - ставит маркер и не делает ссылку на тело сообщения
#      "tree" - не ставит <p> и номер нити, даже если сообщение первое в нити
##############################################################################

sub print_namesubject {
  my $file = $_[0];
  my $indent_num = ($file =~ tr/\.//);

  open (FILE, "$data_dir/$file") || die "Error opening file \"$data_dir/$file\": $!";
  chomp(my $name = <FILE>);
  chomp(my $email = <FILE>);
  chomp(my $ip = <FILE>);
  chomp(my $subject = <FILE>);
  chomp(my $time = <FILE>);
  chomp(my $icon = <FILE>);
  my $text = "";
  while (<FILE>) {
    chomp($_);
    $text = $text.$_;
  }
  close FILE;

  if ($text eq "") { $subject = $subject." (-)"; }
  if (length($text) >= 1024) { $subject = $subject." (+)"; }

  if (!$indent_num and !$_[1]) {
    print "<p>$file. ";
  } else {
    print "&nbsp;" x $indent_num x $indent;
    print "\n";
  }

  if ($_[1] and ($_[1] eq "marked")) {
    print "&#149; &nbsp;";
  }

  if ($icon and $show_icons) {
    print ("<img src=\"$icon_dir/$icon.gif\" width=15 height=15 border=0 alt=\"$icon\">&nbsp;");
  }

  print "<font" if ($namesubject_font or $namesubject_size);
  print " face=\"$namesubject_font\"" if $namesubject_font;
  print " size=\"$namesubject_size\"" if $namesubject_size;
  print ">" if ($namesubject_font or $namesubject_size);

  print "<a href=\"mailto:$email\">" if $email;
  print "<b>" if $name_bold;
  print "<i>" if $name_italic;
  print "<font color=\"$name_color\">" if $name_color;
  print "$name";
  print "</font>" if $name_color;
  print "</i>" if $name_italic;
  print "</b>" if $name_bold;
  print "</a>" if $email;

  print "\n";

  if (!$_[1] or ($_[1] ne "marked")) {
    print qq(<a href="$self_url?);
    if (param('room')) {
      print qq(room=);
      print param('room');
      print ("&");
    }
    print qq(msg=$file);
    print qq(&ac=1) if (param('ac'));
    print qq(">);

  }
  print "<b>" if $subject_bold;
  print "<i>" if $subject_italic;
  print "<font color=\"$subject_color\">" if $subject_color;
  print "$subject";
  print "</font>" if $subject_color;
  print "</i>" if $subject_italic;
  print "</b>" if $subject_bold;
  if (!$_[1] or ($_[1] ne "marked")) {
    print "</a>";
  }

  print "&nbsp;";
  print print_date($time, "short");

  print "</font>" if ($namesubject_font or $namesubject_size);

  if ($time + 86400 >= time) {
    print qq( <sup><font color="red">new!</font></sup>);
  }

  print "<br>\n\n";
}

##############################################################################
# Выводим форму для новой дискуссии
##############################################################################

sub add_new_thread {
  &print_html_header ("Добавление сообщения");
  &print_add_form("");
  &print_html_footer;
}

##############################################################################
# Выводим форму для добавления сообщения
##############################################################################

sub print_add_form {
  my $orig_msg = shift(@_);
  my $quote = "";

  if ($orig_msg) {
    open (FILE, "$data_dir/$orig_msg") || die "Error opening file \"$data_dir/$orig_msg\": $!";
    chomp($orig_name = <FILE>);
    chomp($orig_email = <FILE>);                  # not needed
    chomp($orig_ip = <FILE>);                     # not needed
    chomp($orig_subject = <FILE>);
    chomp($orig_time = <FILE>);
    chomp($orig_icon = <FILE>);                   # not needed
    $subject = "Re: ".$orig_subject;
  } else {
    $subject = "";
  }

  if (param('cite') and $allow_cite) {
    $quote = "Ответ на сообщение \"$subject\" от ".&print_date($orig_time, "short").". $orig_name писал\(а\):\n\n";

    while (<FILE>) {
      $temp = $_;
      chomp ($temp);
      $quote = $quote."&gt;".$temp."\n";
    }
  }

  close FILE;

  my $room = param('room');

  print <<EOD;

<center>
<form action="$self_url" method="POST" onreset="return confirm('Вы действительно хотите очистить заполненную форму?')">
<input type="Hidden" name="post" value="1">
<input type="Hidden" name="room" value="$room">
<input type="Hidden" name="msg_original" value="$orig_msg">
<table border="0" cellspacing="0" cellpadding="0">

<tr><td><font face="$namesubject_font" size="$namesubject_size">Имя</font></td><td><input name="msg_name" size=40 value=""></td></tr>
<tr><td><font face="$namesubject_font" size="$namesubject_size">E-mail</font></td><td><input name="msg_email" size=40 value=""></td></tr>
<tr><td><font face="$namesubject_font" size="$namesubject_size">Заголовок&nbsp;</font></td><td><input name="msg_subject" size=40 value="$subject"></td></tr>
<tr><td colspan="2" align="CENTER">
&nbsp;<br>
<table cellpadding=2 cellspacing=0 border=0><tr>
<td><img src="$icon_dir/note.gif" width=15 height=15 border=0 alt="note">&nbsp;<input type="radio" name="msg_icon" value="note"></td>
<td><img src="$icon_dir/smile.gif" width=15 height=15 alt="smile">&nbsp;<input type="radio" name="msg_icon" value="smile"></td>
<td><img src="$icon_dir/idea.gif" width=15 height=15 alt="idea">&nbsp;<input type="radio" name="msg_icon" value="idea"></td>
<td><img src="$icon_dir/news.gif" width=15 height=15 alt="news">&nbsp;<input type="radio" name="msg_icon" value="news"></td>
<td><img src="$icon_dir/agree.gif" width=15 height=15 alt="agree">&nbsp;<input type="radio" name="msg_icon" value="agree"></td>
<td><img src="$icon_dir/more.gif" width=15 height=15 alt="more">&nbsp;<input type="radio" name="msg_icon" value="more"></td>
</tr><tr>
<td><img src="$icon_dir/question.gif" width=15 height=15 alt="question">&nbsp;<input type="radio" name="msg_icon" value="question"></td>
<td><img src="$icon_dir/sad.gif" width=15 height=15 alt="sad">&nbsp;<input type="radio" name="msg_icon" value="sad"></td>
<td><img src="$icon_dir/warning.gif" width=15 height=15 alt="warning">&nbsp;<input type="radio" name="msg_icon" value="warning"></td>
<td><img src="$icon_dir/feedback.gif" width=15 height=15 alt="feedback">&nbsp;<input type="radio" name="msg_icon" value="feedback"></td>
<td><img src="$icon_dir/disagree.gif" width=15 height=15 alt="disagree">&nbsp;<input type="radio" name="msg_icon" value="disagree"></td>
<td><img src="$icon_dir/dot.gif" width=15 height=15 alt="">&nbsp;<input type="radio" name="msg_icon" value="" checked></td>
</tr></table>
</td></tr>
<tr><td colspan="2"><font face="$namesubject_font" size="$namesubject_size">Текст</font><br><textarea name="msg_text" wrap="VIRTUAL" cols=50 rows=8>$quote</textarea></td></tr>
<tr><td colspan="2" align="CENTER">&nbsp;<br><input type="submit" value="Отправить">&nbsp;<input type="reset" value="Очистить"></td></tr>
</table>
</form>
</center>

EOD
}

##############################################################################
# Добавляем сообщение
##############################################################################

sub add_message {

# Из формы приходят:  
# msg_name, msg_email, msg_subject, msg_original, msg_icon, msg_text
# edited: msg_ip, msg_time

  if (-e "$deny_ip") {
    my $blocked = 0;
    open (BLOCKED_IP, "$deny_ip") || die "Error opening file \"$data_dir/$deny_ip\": $!";
    while (<BLOCKED_IP>) {
      chomp($_);
      if ($_ eq $ENV{'REMOTE_ADDR'}) { $blocked = 1; }
    }
    close BLOCKED_IP;
    if ($blocked) { &show_sorry_message; }
  }

  my $new_msg_name;

  if (param('msg_original')) {
    my $orig_message = param('msg_original');
    my @answers = grep (/^$orig_message\.\d+$/, @messages);
    if ($#answers+1 == 0) {
      $new_msg_name = $orig_message.".1";
    } else {
      @answers = sort ({&cmp_msgs($a, $b)} @answers);
      @answers = reverse @answers;
      $tmp = $answers[0];
      while (index($tmp, ".") != -1) {
        $tmp = substr($tmp, index($tmp, ".")+1);
      }
      $tmp = $tmp + 1;
      $new_msg_name = $orig_message.".".$tmp;
    }
  } else {
    my @threads = grep (/^\d+$/, @messages);
    @threads = sort ({&cmp_msgs($a, $b)} @threads);
    @threads = reverse @threads;
    $new_msg_name = $threads[0] + 1;
  }

  if (-e "$data_dir/$new_msg_name") {
    error ("Неопределенная ошибка! Пожалуйста, сообщите вебмастеру");
  }

  if (param('edited') and $admin) {
    $new_msg_name = param('msg_original');
  }

  my $msg_name = param('msg_name');         # контроль введенного имени
  $msg_name =~ s/<.*?>//g;                  # убрать все тэги
#  $msg_name =~ s/>/&gt;/g;                  # заменить > на &gt;
#  $msg_name =~ s/</&lt;/g;                  # заменить < на &lt;

  my $msg_subject = param('msg_subject');   # контроль введенной темы
  $msg_subject =~ s/<.*?>//g;               # убрать все тэги
#  $msg_subject =~ s/>/&gt;/g;               # заменить > на &gt;
#  $msg_subject =~ s/</&lt;/g;               # заменить < на &lt;

  my $msg_text = param('msg_text');         # контроль введенного текста
  $msg_text =~ s/<.*?>//g;                  # убрать все тэги
  $msg_text =~ s/>/&gt;/g;                  # заменить > на &gt;
  $msg_text =~ s/</&lt;/g;                  # заменить < на &lt;

  if (($msg_subject ne "") or ($msg_text ne "")) {

    if ($msg_name eq "") { $msg_name = "Аноним"; }
    if ($msg_subject eq "") { $msg_subject = "[без темы]"; }

    open (MSG_FILE, ">$data_dir/$new_msg_name") || die "Error opening file \"$data_dir/$new_msg_name\": $!";

    print MSG_FILE $msg_name."\n";
    print MSG_FILE param('msg_email')."\n";
    if (param('edited') and $admin) {
      print MSG_FILE param('msg_ip')."\n";
    } else {
      print MSG_FILE "$ENV{'REMOTE_ADDR'}"."\n";
    }
    print MSG_FILE $msg_subject."\n";
    if (param('edited') and $admin) {
      print MSG_FILE param('msg_time')."\n";
    } else {
      print MSG_FILE time."\n";
    }
    print MSG_FILE param('msg_icon')."\n";
    print MSG_FILE $msg_text."\n";

    close MSG_FILE;

    print qq(<meta http-equiv="Refresh" content="0; URL=$self_url);
    if (param('room')) {
      print qq(?room=);
      print param('room');
    }
    print qq(">);

  } else {
    &print_html_header("Ошибка!");
    print qq(<h3><center>Ошибка: не заполнены поля "Заголовок" и/или "Текст"!</center></h3><p>);
    print qq(<a href="javascript:history.go(-1);"><b>Попробовать заново</b></a>);
    &print_html_footer;
  }

}

##############################################################################
# Удаляем сообщение (и ответы на него, если есть)
##############################################################################

sub admin_remove_msg {
  my $msg_to_remove = shift(@_);
  my @thread_to_remove = grep (/^$msg_to_remove(\.|$)/, @messages);
  foreach $unlucky_message (@thread_to_remove) {
    unlink "$data_dir/$unlucky_message";
  }
  print qq(<meta http-equiv="Refresh" content="0; URL=$self_url);
  if (param('room')) {
    print qq(?room=);
    print param('room');
  }
  if (param('ac')) {
    if (param('room')) {
      print ("&");
    } else {
      print ("?");
    }
    print qq(ac=1);
  }
  print qq(">);
}

##############################################################################
# Редактируем сообщение
##############################################################################

sub admin_edit_msg {
  my $msg_to_edit = shift(@_);
  &print_html_header ("Редактирование сообщения");

  open (FILE, "$data_dir/$msg_to_edit") || die "Error opening file \"$data_dir/$msg_to_edit\": $!";
  chomp($orig_name = <FILE>);
  chomp($orig_email = <FILE>);
  chomp($orig_ip = <FILE>);
  chomp($orig_subject = <FILE>);
  chomp($orig_time = <FILE>);
  chomp($orig_icon = <FILE>);

  my $orig_text = "";

  while (<FILE>) {
    chomp($temp = $_);
    $orig_text = $orig_text.$temp;
  }

  my $room = param('room');

  print <<EOD;

<center>
<form action="$self_url" method="POST" onreset="return confirm('Вы действительно хотите очистить заполненную форму?')">
<input type="Hidden" name="post" value="1">
<input type="Hidden" name="edited" value="1">
<input type="Hidden" name="room" value="$room">
<input type="Hidden" name="msg_original" value="$msg_to_edit">
<input type="Hidden" name="msg_ip" value="$orig_ip">
<input type="Hidden" name="msg_time" value="$orig_time">
<table border="0" cellspacing="0" cellpadding="0">

<tr><td><font face="$namesubject_font" size="$namesubject_size">Имя</font></td><td><input name="msg_name" size=40 value="$orig_name"></td></tr>
<tr><td><font face="$namesubject_font" size="$namesubject_size">E-mail</font></td><td><input name="msg_email" size=40 value="$orig_email"></td></tr>
<tr><td><font face="$namesubject_font" size="$namesubject_size">Заголовок&nbsp;</font></td><td><input name="msg_subject" size=40 value="$orig_subject"></td></tr>
<tr><td colspan="2" align="CENTER">
&nbsp;<br>
<table cellpadding=2 cellspacing=0 border=0><tr>

EOD

  print qq(<td><img src="$icon_dir/note.gif" width=15 height=15 border=0 alt="note">&nbsp;<input type="radio" name="msg_icon" value="note");
  if ($orig_icon eq "note") { print qq( checked); }
  print qq(></td>);
  print qq(<td><img src="$icon_dir/smile.gif" width=15 height=15 alt="smile">&nbsp;<input type="radio" name="msg_icon" value="smile");
  if ($orig_icon eq "smile") { print qq( checked); }
  print qq(></td>);
  print qq(<td><img src="$icon_dir/idea.gif" width=15 height=15 alt="idea">&nbsp;<input type="radio" name="msg_icon" value="idea");
  if ($orig_icon eq "idea") { print qq( checked); }
  print qq(></td>);
  print qq(<td><img src="$icon_dir/news.gif" width=15 height=15 alt="news">&nbsp;<input type="radio" name="msg_icon" value="news");
  if ($orig_icon eq "news") { print qq( checked); }
  print qq(></td>);
  print qq(<td><img src="$icon_dir/agree.gif" width=15 height=15 alt="agree">&nbsp;<input type="radio" name="msg_icon" value="agree");
  if ($orig_icon eq "agree") { print qq( checked); }
  print qq(></td>);
  print qq(<td><img src="$icon_dir/more.gif" width=15 height=15 alt="more">&nbsp;<input type="radio" name="msg_icon" value="more");
  if ($orig_icon eq "more") { print qq( checked); }
  print qq(></td>);
  print qq(</tr><tr>);
  print qq(<td><img src="$icon_dir/question.gif" width=15 height=15 alt="question">&nbsp;<input type="radio" name="msg_icon" value="question");
  if ($orig_icon eq "question") { print qq( checked); }
  print qq(></td>);
  print qq(<td><img src="$icon_dir/sad.gif" width=15 height=15 alt="sad">&nbsp;<input type="radio" name="msg_icon" value="sad");
  if ($orig_icon eq "sad") { print qq( checked); }
  print qq(></td>);
  print qq(<td><img src="$icon_dir/warning.gif" width=15 height=15 alt="warning">&nbsp;<input type="radio" name="msg_icon" value="warning");
  if ($orig_icon eq "warning") { print qq( checked); }
  print qq(></td>);
  print qq(<td><img src="$icon_dir/feedback.gif" width=15 height=15 alt="feedback">&nbsp;<input type="radio" name="msg_icon" value="feedback");
  if ($orig_icon eq "feedback") { print qq( checked); }
  print qq(></td>);
  print qq(<td><img src="$icon_dir/disagree.gif" width=15 height=15 alt="disagree">&nbsp;<input type="radio" name="msg_icon" value="disagree");
  if ($orig_icon eq "disagree") { print qq( checked); }
  print qq(></td>);
  print qq(<td><img src="$icon_dir/dot.gif" width=15 height=15 alt="">&nbsp;<input type="radio" name="msg_icon" value="");
  if ($orig_icon eq "") { print qq( checked); }
  print qq(></td>);

  print <<EOD;

</tr></table>
</td></tr>
<tr><td colspan="2"><font face="$namesubject_font" size="$namesubject_size">Текст</font><br><textarea name="msg_text" wrap="VIRTUAL" cols=50 rows=8>$orig_text</textarea></td></tr>
<tr><td colspan="2" align="CENTER">&nbsp;<br><input type="submit" value="Отправить">&nbsp;<input type="reset" value="Очистить"></td></tr>
</table>
</form>
</center>

EOD

#  print $orig_name."|||".$orig_text;

#  print "Edit: $data_dir/$msg_to_edit";
  &print_html_footer;
}

##############################################################################
# Возвращаем дату и время
##############################################################################
# Вызов: print_date(time, ["short"])
# Где: "short" - выводит укороченный вариант
##############################################################################

sub print_date {
  my @months = ('Января', 'Февраля', 'Марта', 'Апреля', 'Мая', 'Июня',
                'Июля', 'Августа', 'Сентября', 'Октября', 'Ноября', 'Декабря'); 

  my @short_months = ('Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн',
                      'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек');

  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($_[0]);

  if ($mday < 10) { $mday = "0$mday"; }
  my $full_year = $year + 1900;

  if ($year > 99) { $year = $year - 100; }
  if ($year < 10) { $year = "0$year"; }

  if ($hour < 10) { $hour = "0$hour"; }
  if ($min < 10) { $min = "0$min"; }
  if ($sec < 10) { $sec = "0$sec"; }

  if ($_[1] eq "short") {
    return "$mday\-$short_months[$mon]-$year \($hour:$min\)";
  } else {
    return "$mday $months[$mon] $full_year \($hour:$min:$sec\)";
  }
}

##############################################################################
# Печатаем открывающие тэги HTML'а
##############################################################################

sub print_html_header {
  print qq(<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0//EN">\n);
  print qq(<html>\n);
  print qq(<head>\n);
  if ($_[0]) {
    print qq(<title>$_[0] : );
  } else {
    print qq(<title>);
  }
  if (param('room')) {
    my $room = $rooms{param('room')};
    print qq($room : );
  }
  print qq($title</title>\n);

  print qq(<meta name="document-state" content="dynamic">\n);
  print qq(<meta name="robots" content="index, follow">\n);
  print qq(<meta name="description" content="$description">\n);
  print qq(<meta name="keywords" content="$keywords">\n);
  print qq(<link rel=stylesheet href="$css_url" type="text/css">\n) if $css_url;
  print qq(</head>\n);
  print qq($body_tag\n\n);

  open (TOP_HTML, $top_html) || die "Error opening file \"$top_html\": $!";
  while (<TOP_HTML>) { print; }
  close TOP_HTML;

  print qq(<p><center><b>);
  print qq(<a href="$hp_url">[$hp_title]</a><br>\n) if ($hp_url and $hp_title);
  print qq(<a href="$self_url?);
  if (param('room')) {
    print qq(room=);
    print param('room');
    print ("&");
  }
  print qq(add=1);
  print qq(&ac=1) if (param('ac'));
  print qq(">Новая дискуссия</a> &nbsp; );
  if (param('ac')) {
    print qq(<a href="$self_url);
    if (param('room')) {
      print qq(?room=);
      print param('room');
    }
    print qq(">Читать с конца</a></b><br>\n);
  } else {
    print qq(<a href="$self_url?);
    if (param('room')) {
      print qq(room=);
      print param('room');
      print ("&");
    }
    print qq(ac=1">Читать с начала</a></b><br>\n);
  }
  if ($admin) {
    print qq(<b><font color="red">(Режим администрирования)</font> );
    print qq(<a href="$self_url?out=1">Выход</a>);
    print qq(</b>);
  }

  print qq(</center>\n\n);
}

##############################################################################
# Печатаем закрывающие тэги HTML'а
##############################################################################

sub print_html_footer {
  my $num_messages = $#messages + 1;
  my @threads = grep (/^\d+$/, @messages);
  my $num_threads = $#threads + 1;
  my $num_pages = ($num_threads/$page_threads);
  if (int($num_pages) < $num_pages) { $num_pages = int(++$num_pages); }

  print qq(\n\n<p>Статистика: &nbsp;);
  print qq(сообщений $num_messages, нитей $num_threads, страниц $num_pages.<br>\n);

  open (BOTTOM_HTML, $bottom_html) || die "Error opening file \"$bottom_html\": $!";
  while (<BOTTOM_HTML>) { print; }
  close TOP_HTML;

  print qq(</body>\n);
  print qq(</html>);
}

##############################################################################
# Сравниваем номера сообщений
##############################################################################

sub cmp_msgs {
  my $a = shift(@_);
  my $b = shift(@_);

  my $a_sh;
  my $b_sh;

  if (index($a, ".") != -1) { $a_sh = substr($a, 0, index($a, ".")); }
  if (!$a_sh) { $a_sh = $a; }
  if (index($b, ".") != -1) { $b_sh = substr($b, 0, index($b, ".")); }
  if (!$b_sh) { $b_sh = $b; }

  if ($a_sh != $b_sh) {
    return ($a_sh <=> $b_sh);
  } elsif (index($a, ".") == -1) {
    return -1;
  } elsif (index($b, ".") == -1) {
    return 1;
  } else {
    $a_sh = substr($a, index($a, ".")+1);
    $b_sh = substr($b, index($b, ".")+1);
    return &cmp_msgs($a_sh, $b_sh);
  }
}

##############################################################################
# Приносим извинения заблокированным IP
##############################################################################

sub show_sorry_message {
  open (SORRY_FILE, "$deny_ip_html") || die "Error opening file \"$deny_ip_html\": $!";
  while (<SORRY_FILE>) { print; }
  close SORRY_FILE;
  die;
}

##############################################################################
# Проверяем пароль и ставим куку-пропуск
##############################################################################

sub set_admin {
  if (param('change_password')) {                # меняем пароль
    print "Content-type: text/html\n\n";
    if (-e "$data_dir/admin.pwd") {
      open (PASS, "$data_dir/admin.pwd") || die "Error opening password file : $!";
      chomp ($real_password = <PASS>);
      close PASS;
      if (crypt(param('password'), $real_password) eq $real_password) {
        if (param('new_password1') eq param('new_password2') and param('new_password1') ne "") {
          open (PASS, ">$data_dir/admin.pwd") || die "Error opening password file : $!";
          my $salt = join '', ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[rand 64, rand 64];
          my $crypted_new_password = crypt(param('new_password1'),$salt);
          print PASS $crypted_new_password;
          close PASS;
          print "Пароль заменен!<br>";
          print "Новый пароль: <b>".param('new_password1')."</b>.";
        } else {
          print "Новый пароль введен неверно!";
        }
      } else {
        print "Неверный пароль!";
      }
    } else {                                     # ставим новый пароль
      if (param('new_password1') eq param('new_password2') and param('new_password1') ne "") {
        open (PASS, ">$data_dir/admin.pwd") || die "Error opening password file : $!";
        my $salt = join '', ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[rand 64, rand 64];
        my $crypted_new_password = crypt(param('new_password1'),$salt);
        print PASS $crypted_new_password;
        close PASS;
        print "Установлен новый пароль!<br>";
        print "Новый пароль: <b>".param('new_password1')."</b>.";
      } else {
        print "Новый пароль введен неверно!";
      }
    }
  } else {                                       # не меняем пароль
    open (PASS, "$data_dir/admin.pwd") || die "Error opening password file : $!";
    chomp ($real_password = <PASS>);
    close PASS;
    if (crypt(param('password'), $real_password) eq $real_password) {
      my $cookie = cookie(-name=>"password",
                          -value=>$real_password,
                          -expires=>'+1h');
      print header(-cookie=>$cookie);
      my $self_url = url(-relative=>1);
      print qq(<meta http-equiv="Refresh" content="0; URL=$self_url">);
    } else {
      print "Content-type: text/html\n\n";
      print "Неверный пароль!";
    }
  }
}

##############################################################################
# Проверяем админскую куку
##############################################################################

sub check_if_admin {
  my $pwd_cookie = cookie("password");
  open (PASS, "$data_dir/admin.pwd") || die "Error opening password file : $!";
  chomp ($real_password = <PASS>);
  close PASS;
  if ($pwd_cookie eq $real_password) {
    $admin = 1;
  } else {
    $admin = 0;
  }
}

##############################################################################
# Прибиваем куку-пропуск (вернее пишем вместо нее пустую)
##############################################################################

sub exit_admin {
  my $cookie = cookie(-name=>"password",
                      -value=>"");
  print header(-cookie=>$cookie);
  my $self_url = url(-relative=>1);
  print qq(<meta http-equiv="Refresh" content="0; URL=$self_url">);
}

##############################################################################
# Ошибки программы
##############################################################################

sub error {
  &print_html_header ("Ошибка!");
  print ("<h3>@_[0]</h3>");
  &print_html_footer;
  die;
}

##############################################################################
