import lancedb
import sys

def delete_docchunkdb():
    """
    Deletes the docchunkdb database.
    """
    try:
        db = lancedb.connect("s3+ddb://smart-suite-lance-db-bucket/?ddbTableName=smart-suite-lance-db-table")
        db.drop_table("chunks")
        db.drop_table("documents")
        print("docchunkdb deleted successfully.")
    except Exception as e:
        print(f"An error occurred while deleting docchunkdb: {e}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python _delete_docchunkdb.py confirmed")
        sys.exit(1)
    if sys.argv[1] != "confirmed":
        print("Please run the script with 'confirmed' argument to delete docchunkdb.")
        sys.exit(1)
    delete_docchunkdb()
