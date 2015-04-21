####################################################################################################################################
# LOCK MODULE
####################################################################################################################################
package BackRest::Lock;

use strict;
use warnings FATAL => qw(all);
use Carp qw(confess longmess);

use Fcntl qw(:DEFAULT :flock);
use File::Basename qw(dirname);

use lib dirname($0) . '/../lib';
use BackRest::Config qw(optionGet OPTION_REPO_PATH OPTION_STANZA);
use Exporter qw(import);

our @EXPORT = qw(version_get
                 data_hash_build trim common_prefix file_size_format execute
                 log log_file_set log_level_set test_set test_get test_check
                 lock_file_create lock_file_remove hsleep wait_remainder
                 ini_save ini_load timestamp_string_get timestamp_file_string_get
                 TRACE DEBUG ERROR ASSERT WARN INFO OFF true false
                 TEST TEST_ENCLOSE TEST_MANIFEST_BUILD TEST_BACKUP_RESUME TEST_BACKUP_NORESUME FORMAT);

####################################################################################################################################
# Lock Types
####################################################################################################################################
use constant
{
    LOCK_TYPE_ARCHIVE   => 'archive',
    LOCK_TYPE_BACKUP    => 'backup',
    LOCK_TYPE_EXPIRE    => 'expire',
    LOCK_TYPE_RESTORE   => 'backup'
};

our @EXPORT = qw(LOCK_TYPE_ARCHIVE LOCK_TYPE_BACKUP LOCK_TYPE_EXPIRE LOCK_TYPE_RESTORE);

####################################################################################################################################
# Global lock type and handle
####################################################################################################################################
my $strCurrentLockType;
my $hCurrentLockHandle;

####################################################################################################################################
# lockPathName
#
# Get the base path where the lock file will be stored.
####################################################################################################################################
sub lockPathName
{
    my $strRepoPath = shift;

    return "${strRepoPath}/lock";
}

####################################################################################################################################
# lockFileName
#
# Get the lock file name.
####################################################################################################################################
sub lockFileName
{
    my $strLockType = shift;
    my $strStanza = shift;
    my $strRepoPath = shift;

    return lockPathName($strRepoPath) . "/lock/${strStanza}-${strLockType}.lock";
}

####################################################################################################################################
# lockCreate
#
# Attempt to create the specified lock.  If the lock is taken by another process return false, else take the lock and return true.
####################################################################################################################################
sub lockCreate
{
    my $strLockType = shift;

    # Cannot proceed if a lock is currently held
    if (defined($strCurrentLockType))
    {
        confess &lock(ASSERT, "${strCurrentLockType} lock is already held");
    }

    # Attempt to open the lock file
    $strLockFile = lockFileName($strLockType, optionGet(OPTION_STANZA), optionGet(OPTION_REPO_PATH));

    sysopen($hCurrentLockFile, $strLockFile, O_WRONLY | O_CREAT)
        or confess &log(ERROR, "unable to open lock file ${strLockFile}");

    # Attempt to lock the lock file
    if (!flock($hCurrentLockHandle, LOCK_EX | LOCK_NB))
    {
        close($hCurrentLockHandle);
        return false;
    }

    # Set current lock type so we know we have a lock
    $strCurrentLockType = $strLockType;

    # Lock was successful
    return true;
}

####################################################################################################################################
# lockRemove
####################################################################################################################################
sub lockRemove
{
    my $strLockType = shift;
    
    # Fail if there is no lock
    if (!defined($strCurrentLockType))
    {
        confess &log(ASSERT, 'no lock is currently held');
    }

    # Fail if the lock being released is not the one held
    if ($strLockType ne $strCurrentLockType)
    {
        confess &log(ASSERT, "cannot remove lock ${strLockType} since ${strCurrentLockType} is currently held");
    }

    # Close the file
    close($hCurrentLockFile);
    undef($strCurrentLockType);
    undef($hCurrentLockFile);

    # Remove the file
    unlink($strCurrentLockType);
}

1;
