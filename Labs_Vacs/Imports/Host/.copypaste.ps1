# Deplace tous les fichiers du dossiers Host dans le dossier W:\Partage\Workshop\host, en conservant l'arborescence (sous-dossiers) et en ecrasant les fichiers existants.
xcopy "C:\Users\Baine\SynologyDrive\GitHub\Labs\Labs_Vacs\Imports\Host" "W:\Host" /s /e /y
xcopy "C:\Users\Baine\SynologyDrive\GitHub\Labs\Labs_Vacs\Imports\Host" "\\192.168.0.185\Workgroup\host" /s /e /y