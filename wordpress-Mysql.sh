#!/bin/bash

# Função para exibir uma linha de separação
function print_separator {
    echo "+------------------------------------------------------------------------------+"
}

# Função para executar um comando e verificar se ocorreu um erro
function run_command {
    local command="$1"
    echo "| Executando: $command"
    eval "$command"
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "| Erro: O comando \"$command\" falhou com código de saída $exit_code"
        exit $exit_code
    fi
}

# Atualiza a lista de pacotes disponíveis e suas versões
print_separator
echo "|                 Atualizando pacotes                                          |"
print_separator
run_command "apt-get update"

# Instala o servidor MySQL e o cliente MySQL
print_separator
echo "|         Instalando MySQL Server e Client                                     |"
print_separator
run_command "apt-get install -y mysql-server mysql-client"

# Pede ao usuário para inserir o nome de usuário e senha do MySQL
echo "| Insira o nome de usuário do MySQL que você deseja criar:"
read -r mysql_user
echo "| Insira a senha do MySQL para o usuário $mysql_user:"
read -rs mysql_password

# Cria um banco de dados no MySQL, cria um usuário e concede privilégios
print_separator
echo "|               Configurando MySQL                                             |"
print_separator
mysql_commands=$(cat <<EOF
CREATE DATABASE IF NOT EXISTS wordpress CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$mysql_user'@'localhost' IDENTIFIED BY '$mysql_password';
GRANT ALL PRIVILEGES ON wordpress.* TO '$mysql_user'@'localhost';
FLUSH PRIVILEGES;
EOF
)
run_command "echo \"$mysql_commands\" | mysql -u root -p"

# Instala o servidor Apache e as extensões PHP necessárias para o WordPress
print_separator
echo "|           Instalando Apache e PHP no Ubuntu Linux                            |"
print_separator
run_command "apt-get install -y apache2 php7.2 php7.2-mysql libapache2-mod-php7.2"

# Reinicia o serviço do Apache para aplicar as alterações
run_command "service apache2 restart"

# Ativa os módulos mod_rewrite e SSL do Apache
print_separator
echo "|             Ativando módulos do Apache                                       |"
print_separator
run_command "a2enmod rewrite"
run_command "a2enmod ssl"
run_command "service apache2 restart"

# Edita o arquivo de configuração do PHP para ajustar as configurações necessárias para o WordPress
print_separator
echo "|         Configurando arquivo php.ini                                         |"
print_separator
php_ini_path=$(php -i | grep 'Loaded Configuration File' | cut -d ' ' -f 5)
php_ini_backup="${php_ini_path}.backup"
run_command "cp $php_ini_path $php_ini_backup"
run_command "sed -i 's/;file_uploads = On/file_uploads = On/' $php_ini_path"
run_command "sed -i 's/;memory_limit = .*/memory_limit = 256M/' $php_ini_path"
run_command "sed -i 's/;post_max_size = .*/post_max_size = 32M/' $php_ini_path"
run_command "sed -i 's/;max_input_time = .*/max_input_time = 60/' $php_ini_path"
run_command "sed -i 's/;max_input_vars = .*/max_input_vars = 4440/' $php_ini_path"

# Reinicia o servidor Apache manualmente
print_separator
echo "|           Reiniciando o servidor Apache                                      |"
print_separator
run_command "service apache2 restart"

# Baixa a última versão do WordPress e extrai o pacote
print_separator
echo "|          Baixando e instalando WordPress                                     |"
print_separator
run_command "cd /tmp"
run_command "wget -O latest.tar.gz https://wordpress.org/latest.tar.gz"
run_command "tar -zxvf latest.tar.gz"

# Move a pasta WordPress para dentro do diretório da unidade raiz do Apache
run_command "mv wordpress /var/www/html/"
run_command "chown -R www-data:www-data /var/www/html/wordpress"

# Cria e edita o arquivo de configuração do WordPress wp-config.php
print_separator
echo "|        Configurando arquivo wp-config.php                                    |"
print_separator
run_command "cp /var/www/html/wordpress/wp-config-sample.php /var/www/html/wordpress/wp-config.php"
run_command "sed -i 's/database_name_here/wordpress/g' /var/www/html/wordpress/wp-config.php"
run_command "sed -i 's/username_here/$mysql_user/g' /var/www/html/wordpress/wp-config.php"
run_command "sed -i 's/password_here/$mysql_password/g' /var/www/html/wordpress/wp-config.php"

echo "|-------------------------------------------|"
echo "|       Instalação concluída com sucesso!   |"
echo "|-------------------------------------------|"

