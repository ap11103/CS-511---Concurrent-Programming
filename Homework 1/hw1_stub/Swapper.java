public class Swapper implements Runnable {
    private int offset;
    private Interval interval;
    private String content;
    private char[] buffer;

    public Swapper(Interval interval, String content, char[] buffer, int offset) {
        this.offset = offset;
        this.interval = interval;
        this.content = content;
        this.buffer = buffer;
    }

    @Override
    public void run() {
        // TODO: Implement me!

        //getting the size of the content by using .length()
        int size = content.substring(interval.getX(), interval.getY()).length();
        //int size = (interval.getX() - interval.getY()) + 1
        //converting the content to char array
        char[] arr = content.substring(interval.getX(), interval.getY()).toCharArray();
        //temp to store the char
        char temp = 0;
        for(int i = 0; i < size ; i++) {
            temp = arr[i];
            //store the char at the offset
            buffer[offset] = temp;
            offset++;

        }
            
    }
}