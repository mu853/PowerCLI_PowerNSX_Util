## ����͉��H

vCenter����A���[���̏������o���c�[���ł��B
PowerCLI�Ŏ��o����CSV�ɕۑ��AExcel�}�N���Ő��`�Ƃ�������ŁA�ŏI�I�Ȑ�������Excel�t�@�C���ɂȂ�܂��B



## �g����

0. ��ƒ[����PowerCLI���C���X�g�[������
PowerShell���J���ĉ��L�R�}���h�����s
```
Install-Module VMware.PowerCLI
```

1. Export-vCenterAlarmInfo.ps1 ��ǂݍ���
PowerCLI���J���āA�t�@�C���̒��g���R�s�y

2. ���L�R�}���h�����s����CSV�쐬
```
Connect-VIServer <vCenter�T�[�o�[��IP or FQDN> -User administrator@vsphere.local -Password <�p�X���[�h>
Export-vCenterAlarm | Export-Csv -Encoding UTF8 -NoTypeInformation -Path <�ۑ�����CSV�̃t���p�X.csv>
```

4. CSV�𐮌`
* vCener�A���[��CSV���`�p�}�N��.xlsm ���J���āA��ʏ㕔�́u�R���e���c�̗L�����v���N���b�N���ă}�N����L��������
* �ۑ�����CSV���J���iExcel�łˁj
* CSV���J������ʂ��O�ʂɂ����ԂŁAAlt + F8 �������āu���ꂢ�ɂ����v�}�N�������s
* Excel�`���ŕۑ�

