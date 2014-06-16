console.log('How goes it?');
if (true) {
    console.log('True works');
} else {
    console.log('Yar matey, stuff broken.');
}
function quilted_ducks(banana) {
    console.log('Duck duck duckkk', banana);
}
try {
    console.log('Try');
    throw 'Fail';
} catch (e) {
    console.log('NOPED');
}
quilted_ducks(1234);
