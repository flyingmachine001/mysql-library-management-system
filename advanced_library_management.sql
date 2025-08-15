-- Add indexes for faster search
CREATE INDEX idx_books_title ON books(title);
CREATE INDEX idx_members_email ON members(email);

-- Add a column for book availability
ALTER TABLE books ADD COLUMN available BOOLEAN DEFAULT TRUE;

-- Trigger: Automatically set book availability when issued
DELIMITER //
CREATE TRIGGER after_issue_book
AFTER INSERT ON issued_books
FOR EACH ROW
BEGIN
    UPDATE books SET available = FALSE WHERE book_id = NEW.book_id;
END;
//
DELIMITER ;

-- Trigger: Automatically set book availability when returned
DELIMITER //
CREATE TRIGGER after_return_book
AFTER UPDATE ON issued_books
FOR EACH ROW
BEGIN
    IF NEW.return_date IS NOT NULL THEN
        UPDATE books SET available = TRUE WHERE book_id = NEW.book_id;
    END IF;
END;
//
DELIMITER ;

-- Stored Procedure: Issue a book (checks availability)
DELIMITER //
CREATE PROCEDURE IssueBook(IN p_book_id INT, IN p_member_id INT)
BEGIN
    DECLARE book_status BOOLEAN;
    SELECT available INTO book_status FROM books WHERE book_id = p_book_id;
    IF book_status THEN
        INSERT INTO issued_books (book_id, member_id, issue_date)
        VALUES (p_book_id, p_member_id, CURDATE());
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Book not available';
    END IF;
END;
//
DELIMITER ;

-- Stored Procedure: Return a book (sets return date)
DELIMITER //
CREATE PROCEDURE ReturnBook(IN p_issue_id INT)
BEGIN
    UPDATE issued_books SET return_date = CURDATE() WHERE issue_id = p_issue_id AND return_date IS NULL;
END;
//
DELIMITER ;

-- View: List currently issued books
CREATE VIEW v_currently_issued AS
SELECT ib.issue_id, b.title, m.name, ib.issue_date
FROM issued_books ib
JOIN books b ON ib.book_id = b.book_id
JOIN members m ON ib.member_id = m.member_id
WHERE ib.return_date IS NULL;

-- Query: Use the view to get currently issued books
SELECT * FROM v_currently_issued;

-- Audit table for tracking changes
CREATE TABLE audit_log (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(50),
    table_name VARCHAR(50),
    record_id INT,
    action_time DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Example: Insert audit log on member addition (could be done with triggers)
DELIMITER //
CREATE TRIGGER after_member_add
AFTER INSERT ON members
FOR EACH ROW
BEGIN
    INSERT INTO audit_log(action, table_name, record_id)
    VALUES ('INSERT', 'members', NEW.member_id);
END;
//
DELIMITER ;