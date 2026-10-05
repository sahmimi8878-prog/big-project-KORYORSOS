module.exports = {
  getCurrentDateForToken() {
    const now = new Date();
    const formattedDate = new Intl.DateTimeFormat('en-GB', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
    }).format(now).replace(/\//g, '-');
    return formattedDate;
  }
};