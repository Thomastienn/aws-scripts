echo "This will delete documents and chunks table in the database."
read -p "Are you sure you want to continue? (y/n): " confirm
if [[ $confirm == "y" || $confirm == "Y" ]]; then
    echo "Confirm twice to delete the tables."
    read -p "Confirm again (y/n): " confirm2
    if [[ $confirm2 == "y" || $confirm2 == "Y" ]]; then
        echo "Did you miss click or you actually want to delete the tables?"
        read -p "Confirm again (y/n): " confirm3
        if [[ $confirm3 == "y" || $confirm3 == "Y" ]]; then
            echo "Deleting documents and chunks table in the database..."
            source ./venv/bin/activate && python _delete_docchunkdb.py confirmed
        fi
    fi
fi
