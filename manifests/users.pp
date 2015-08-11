# == Class kafka::users
#
class kafka::users {

  realize ( User['kafka'], Group['kafka'] )

}
