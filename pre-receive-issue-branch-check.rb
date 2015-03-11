#!/usr/bin/env ruby

# Script receives this line on stdin when called for each commit
# < old-value > SP < new-value > SP < ref-name > LF
# http://stackoverflow.com/questions/2569960/git-pre-receive-hook

$error_status = 0 

$regex_ticket = /(^Merge\sbranch{1})(.*)|((^([Tt]icket#\d+){1}(,[Tt]icket#\d+|,#\d+)*)|(^([Tt]icket#none)))(\s|:\s?){1}(.*)/
$regex_issue = /(^Merge\sbranch\s{1}(.*))|(((^([Ii]ssue:(\s)*(\d+)(,\d+)*))|(^([Ii]ssue:(\s)*[Nn]one))))\s*$/

$reqex_extern_ref = $regex_issue

$regex_branch = /(^refs\/heads\/prd\/\w+\/\w+$)|(^refs\/heads\/fea\/\w+$)/

#function, just for ease of testing
def parse_message_for_no_issue_listed(msg,re)
  $no_found = 0
  msg.scan(re) { $no_found += 1 }
  if $no_found == 1
    return true
  else
    return false
  end
end


def parse_message(msg,re)
  if not re.match(msg)
    return false
  else 
    return true
  end
end

# enforced custom commit message format
def check_message_format
  $check_message_status = true
  if $rev_old ==  '0000000000000000000000000000000000000000'
    missed_revs = `git rev-list #{$rev_new}^1..#{$rev_new} --abbrev-commit `.split("\n") 
  else
    missed_revs = `git rev-list #{$rev_old}..#{$rev_new} --abbrev-commit `.split("\n")
  end 
  missed_revs.each do |rev|
    message = `git cat-file commit #{rev} | sed '1,/^$/d'`
    if not parse_message(message,$reqex_extern_ref)
      STDERR.puts "[git-hook ERROR] Pls insert a ref to an issue for SHA1: #{ rev }"
      $check_message_status = false 
    else
      if not parse_message_for_no_issue_listed(message,$reqex_extern_ref)
        STDERR.puts "[git-hook ERROR] Only one line of issue reference allowed - Amount detected: " + $no_found.to_s
      end
    end  
  end
  if $check_message_status  
    STDOUT.puts "[git-hook INFO] Issue check: ok"
  else
    STDERR.puts "[git-hook INFO]  Allowed pattern:"
    STDERR.puts "[git-hook INFO]      " + $reqex_extern_ref.source
    STDERR.puts "[git-hook INFO]" 
    STDERR.puts "[git-hook INFO]  Ex: Issue:1"
    STDERR.puts "[git-hook INFO]  Ex: issue: 1,2"
    STDERR.puts "[git-hook INFO]  Ex: issue: none"
    STDERR.puts "[git-hook INFO]"              
    $error_status = 1
  end 
end

def check_branch
  if not parse_message($ref, $regex_branch)
    STDERR.puts "[git-hook ERROR] You are not allowed to push to branch:"
    STDERR.puts "[git-hook ERROR]     " + $ref
    STDERR.puts "[git-hook INFO]  Allowed pattern:"
    STDERR.puts "[git-hook INFO]      " + $regex_branch.source 
    STDERR.puts "[git-hook INFO]"
    STDERR.puts "[git-hook INFO]  Ex: refs/heads/prd/<product>/<what>"
    STDERR.puts "[git-hook INFO]  Ex: refs/heads/fea/<what>"
    STDERR.puts "[git-hook INFO]"
    $error_status = 1
  else
    STDOUT.puts "[git-hook INFO] Branch check: " + $ref + " : ok"
  end
end

# The "main" method ... when executing this file:
#Only run this if the file itself is being executed
if __FILE__ == $0
  $rev_old, $rev_new, $ref = STDIN.read.split(" ")

  check_branch 

  check_message_format
exit 1

  exit $error_status
end
