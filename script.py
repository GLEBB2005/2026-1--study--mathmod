#!/usr/bin/env python3
"""
Скрипт для автоматического создания релиза с использованием git-flow и standard-version
"""

import json
import subprocess
import sys
import os
from pathlib import Path
from typing import Dict, List, Optional

class ReleaseManager:
    def __init__(self, config_file: str = "release_config.json"):
        """Инициализация менеджера релизов"""
        self.config_file = config_file
        self.config = self.load_config()
        self.work_dir = Path.cwd()
        
    def load_config(self) -> Dict:
        """Загрузка конфигурации из файла"""
        if not os.path.exists(self.config_file):
            print(f"❌ Файл конфигурации {self.config_file} не найден!")
            self.create_config_template()
            sys.exit(1)
        
        with open(self.config_file, 'r', encoding='utf-8') as f:
            return json.load(f)
    
    def create_config_template(self):
        """Создание шаблона конфигурации"""
        template = {
            "version": "1.0.0",
            "repositories": [
                {
                    "name": "origin",
                    "url": "git@github.com:yourusername/yourrepo.git"
                }
            ],
            "git_flow": {
                "develop_branch": "develop",
                "master_branch": "main",  # Исправлено с master на main
                "feature_prefix": "feature/",
                "release_prefix": "release/",
                "hotfix_prefix": "hotfix/"
            },
            "auto_confirm": False
        }
        
        with open(self.config_file, 'w', encoding='utf-8') as f:
            json.dump(template, f, indent=2, ensure_ascii=False)
        
        print(f"✅ Создан шаблон конфигурации: {self.config_file}")
        print("📝 Отредактируйте его перед запуском")
    
    def run_command(self, cmd: List[str], check: bool = True, capture: bool = True) -> subprocess.CompletedProcess:
        """Выполнение команды в shell"""
        print(f"🔧 Выполнение: {' '.join(cmd)}")
        try:
            if capture:
                result = subprocess.run(
                    cmd,
                    cwd=self.work_dir,
                    capture_output=True,
                    text=True,
                    check=check
                )
                if result.stdout:
                    # Фильтруем предупреждения о тегах
                    if "Warning: tag" not in result.stdout and "already exists" not in result.stdout:
                        print(f"📝 {result.stdout.strip()}")
            else:
                result = subprocess.run(
                    cmd,
                    cwd=self.work_dir,
                    check=check
                )
            return result
        except subprocess.CalledProcessError as e:
            print(f"❌ Ошибка: {e.stderr if hasattr(e, 'stderr') else str(e)}")
            if check:
                sys.exit(1)
            return e
    
    def check_git_repo(self) -> bool:
        """Проверка, что мы в git репозитории"""
        result = self.run_command(["git", "rev-parse", "--git-dir"], check=False)
        return result.returncode == 0
    
    def check_git_flow(self) -> bool:
        """Проверка наличия git-flow"""
        result = self.run_command(["git", "flow", "version"], check=False)
        if result.returncode != 0:
            print("❌ git-flow не установлен!")
            print("Установите git-flow:")
            print("  - Mac: brew install git-flow")
            print("  - Linux: apt-get install git-flow")
            print("  - Windows: scoop install git-flow")
            return False
        return True
    
    def check_standard_version(self) -> bool:
        """Проверка наличия standard-version"""
        result = self.run_command(["npx", "standard-version", "--version"], check=False)
        if result.returncode != 0:
            print("❌ standard-version не установлен!")
            print("Установите его: npm install --save-dev standard-version")
            return False
        return True
    
    def git_flow_init(self) -> None:
        """Инициализация git-flow если не инициализирован"""
        # Проверяем, инициализирован ли git-flow
        result = self.run_command(["git", "flow", "config"], check=False)
        if result.returncode != 0:
            print("🔧 Инициализация git-flow...")
            # Настраиваем префикс для тегов
            self.run_command(["git", "config", "gitflow.tag.prefix", "v"], check=False)
            self.run_command([
                "git", "flow", "init", "-d",
                "-d", self.config["git_flow"]["develop_branch"],
                "-m", self.config["git_flow"]["master_branch"]
            ], capture=False)
            print("✅ git-flow инициализирован")
        else:
            print("✅ git-flow уже инициализирован")
    
    def git_flow_release_start(self, version: str) -> None:
        """Создание релизной ветки через git-flow"""
        print(f"🚀 Создание релизной ветки для версии {version}...")
        
        # git flow release start VERSION
        self.run_command([
            "git", "flow", "release", "start", version
        ], capture=False)
        
        print(f"✅ Создана релизная ветка: release/{version}")
    
    def run_standard_version(self, version: str) -> None:
        """Запуск standard-version для обновления версии и changelog"""
        print(f"📝 Запуск standard-version для версии {version}...")
        
        # standard-version обновит package.json и CHANGELOG.md
        self.run_command([
            "npx", "standard-version",
            "--release-as", version,
            "--skip.commit", "true",  # Не коммитим сразу, сделаем сами
            "--skip.tag", "true"      # Не создаем тег, git-flow сделает это
        ], capture=False)
        
        print("✅ standard-version завершил работу")
    
    def commit_release_changes(self, version: str) -> None:
        """Коммит изменений от standard-version"""
        # Добавляем измененные файлы
        self.run_command(["git", "add", "package.json", "package-lock.json", "CHANGELOG.md"], check=False)
        self.run_command(["git", "add", "."], check=False)
        
        # Проверяем, есть ли изменения
        status = self.run_command(["git", "status", "--porcelain"], check=False)
        if status.stdout.strip():
            self.run_command([
                "git", "commit",
                "-m", f"chore(release): {version}"
            ], capture=False)
            print(f"✅ Создан коммит с изменениями для версии {version}")
        else:
            print("ℹ️ Нет изменений для коммита")
    
    def git_flow_release_finish(self, version: str) -> None:
        """Завершение релиза через git-flow"""
        print(f"🏁 Завершение релиза {version}...")
        
        # Настраиваем префикс для тегов перед завершением
        self.run_command(["git", "config", "gitflow.tag.prefix", "v"], check=False)
        
        # git flow release finish создаст тег с префиксом v
        self.run_command([
            "git", "flow", "release", "finish",
            "-m", f"Release {version}",
            version
        ], capture=False)
        
        print(f"✅ Релиз {version} завершен, тег v{version} создан")
    
    def push_to_repositories(self, version: str) -> None:
    """Пуш во все репозитории"""
    master_branch = self.config["git_flow"]["master_branch"]
    develop_branch = self.config["git_flow"]["develop_branch"]
    tag_name = f"v{version}"
    
    # Проверяем существование тега
    tag_check = self.run_command(["git", "tag", "-l", tag_name], check=False)
    if not tag_check.stdout.strip():
        print(f"⚠️ Тег {tag_name} не найден, создаю...")
        self.run_command(["git", "tag", "-a", tag_name, "-m", f"Release {version}"])
    
    for repo in self.config["repositories"]:
        repo_name = repo["name"]
        repo_url = repo["url"]
        
        # Добавляем remote если его нет
        self.run_command(["git", "remote", "add", repo_name, repo_url], check=False)
        
        print(f"📤 Пуш в {repo_name} ({repo_url})...")
        
        # Пушим master принудительно
        self.run_command(["git", "push", "--force", repo_name, master_branch])
        
        # Пушим develop принудительно
        self.run_command(["git", "push", "--force", repo_name, develop_branch])
        
        # Пушим тег принудительно (с префиксом v)
        self.run_command(["git", "push", "--force", repo_name, tag_name])
        
        print(f"✅ Успешно отправлено в {repo_name}")
    
    def verify_release(self, version: str) -> bool:
        """Проверка успешности релиза"""
        tag_name = f"v{version}"
        master_branch = self.config["git_flow"]["master_branch"]
        develop_branch = self.config["git_flow"]["develop_branch"]
        
        checks_passed = True
        
        # Проверяем тег
        result = self.run_command(["git", "tag", "-l", tag_name], check=False)
        if result.stdout.strip():
            print(f"✅ Тег {tag_name} создан")
        else:
            print(f"❌ Тег {tag_name} не найден!")
            checks_passed = False
        
        # Проверяем, что изменения в master
        self.run_command(["git", "checkout", master_branch])
        result = self.run_command(["git", "log", "-1", "--oneline"], check=False)
        print(f"📌 Последний коммит в {master_branch}: {result.stdout.strip()}")
        
        # Проверяем changelog
        changelog_path = self.work_dir / "CHANGELOG.md"
        if changelog_path.exists():
            with open(changelog_path, 'r', encoding='utf-8') as f:
                if version in f.read():
                    print(f"✅ CHANGELOG.md содержит версию {version}")
                else:
                    print(f"⚠️ CHANGELOG.md не содержит версию {version}")
        
        # Возвращаемся в develop
        self.run_command(["git", "checkout", develop_branch])
        
        return checks_passed
    
    def cleanup_old_release_branch(self, version: str) -> None:
        """Очистка старой релизной ветки (git-flow уже удаляет, но на всякий случай)"""
        release_branch = f"release/{version}"
        
        # Проверяем, существует ли еще ветка
        result = self.run_command(["git", "branch", "-l", release_branch], check=False)
        if result.stdout.strip():
            # Пробуем удалить локально
            self.run_command(["git", "branch", "-d", release_branch], check=False)
            # Пробуем удалить на удаленных репозиториях
            for repo in self.config["repositories"]:
                self.run_command(["git", "push", repo["name"], "--delete", release_branch], check=False)
    
    def delete_old_tags_without_v(self, version: str) -> None:
        """Удаление старых тегов без префикса v"""
        old_tag = version  # без v
        new_tag = f"v{version}"
        
        # Проверяем существование старого тега
        tag_check = self.run_command(["git", "tag", "-l", old_tag], check=False)
        if tag_check.stdout.strip():
            print(f"🗑️ Удаляю старый тег {old_tag}...")
            # Удаляем локально
            self.run_command(["git", "tag", "-d", old_tag], check=False)
            # Удаляем на удаленных репозиториях
            for repo in self.config["repositories"]:
                self.run_command(["git", "push", repo["name"], f":{old_tag}"], check=False)
            print(f"✅ Старый тег {old_tag} удален")
    
    def run(self) -> None:
        """Основной метод запуска"""
        print("🚀 Начинаем процесс создания релиза с git-flow...\n")
        
        # Проверки
        if not self.check_git_repo():
            print("❌ Текущая директория не является git репозиторием!")
            sys.exit(1)
        
        if not self.check_git_flow():
            sys.exit(1)
        
        if not self.check_standard_version():
            sys.exit(1)
        
        version = self.config["version"]
        develop_branch = self.config["git_flow"]["develop_branch"]
        master_branch = self.config["git_flow"]["master_branch"]
        
        # Получаем текущую ветку
        current_branch_result = self.run_command(["git", "branch", "--show-current"], check=False)
        current_branch = current_branch_result.stdout.strip()
        
        print(f"📌 Текущая ветка: {current_branch}")
        print(f"📌 Версия релиза: {version}")
        print(f"📌 Develop ветка: {develop_branch}")
        print(f"📌 Master ветка: {master_branch}")
        
        # Проверяем, что мы в develop ветке
        if current_branch != develop_branch:
            print(f"⚠️ Вы не в ветке {develop_branch}")
            response = input(f"Переключиться на {develop_branch}? (y/n): ")
            if response.lower() == 'y':
                self.run_command(["git", "checkout", develop_branch])
                self.run_command(["git", "pull", "origin", develop_branch])
            else:
                print("❌ Операция отменена")
                sys.exit(0)
        
        # Подтверждение
        if not self.config.get("auto_confirm", False):
            response = input("\n✅ Продолжить создание релиза? (y/n): ")
            if response.lower() != 'y':
                print("❌ Операция отменена")
                sys.exit(0)
        
        try:
            # Удаляем старые теги без v
            self.delete_old_tags_without_v(version)
            
            # Настраиваем git-flow на использование префикса v
            self.run_command(["git", "config", "gitflow.tag.prefix", "v"], check=False)
            
            # 1. Инициализируем git-flow если нужно
            self.git_flow_init()
            
            # 2. Создаем релизную ветку через git flow
            self.git_flow_release_start(version)
            
            # 3. Запускаем standard-version для обновления файлов
            self.run_standard_version(version)
            
            # 4. Коммитим изменения от standard-version
            self.commit_release_changes(version)
            
            # 5. Завершаем релиз через git flow (создает тег с префиксом v, мержит в master и develop)
            self.git_flow_release_finish(version)
            
            # 6. Пушим во все репозитории
            self.push_to_repositories(version)
            
            # 7. Очищаем старые релизные ветки
            self.cleanup_old_release_branch(version)
            
            # 8. Проверяем результат
            if self.verify_release(version):
                print("\n" + "="*50)
                print("✅ РЕЛИЗ УСПЕШНО СОЗДАН!")
                print("="*50)
                print(f"📦 Версия: {version}")
                print(f"📝 CHANGELOG обновлен")
                print(f"🏷️  Тег: v{version}")
                print(f"🌿 Ветки: {master_branch} и {develop_branch} обновлены")
                print("🎉 Готово!")
            else:
                print("\n⚠️ Релиз создан, но некоторые проверки не пройдены")
            
        except Exception as e:
            print(f"\n❌ Произошла ошибка: {e}")
            print("🔄 Рекомендуется вручную проверить состояние репозитория")
            print("💡 Выполните: git flow release abort")
            sys.exit(1)

def main():
    """Точка входа"""
    config_file = "release_config.json"
    
    if len(sys.argv) > 1:
        config_file = sys.argv[1]
    
    manager = ReleaseManager(config_file)
    manager.run()

if __name__ == "__main__":
    main()
