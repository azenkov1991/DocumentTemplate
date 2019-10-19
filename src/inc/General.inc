#Define PushToStack(%list, %value) set %list = $LU(%list, $LL(%list)+1, %value)
#Define PopFromStack(%list) $S($LL(%list) > 0:$LI(%list,*),1:"")   if ( $LL(%list) > 0 ) set %list=$LI(%list,1,*-1)

